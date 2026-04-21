// Supabase Edge Function: 카카오 액세스 토큰을 검증하고 Supabase 세션을 발급
// Deno 런타임 — Node.js 문법 사용 금지

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS })
  }

  try {
    const { access_token } = await req.json()
    if (!access_token) throw new Error('access_token이 없습니다')

    // ── 1. 카카오 API로 액세스 토큰 검증 + 사용자 정보 조회 ──────────
    const kakaoRes = await fetch('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${access_token}` },
    })
    if (!kakaoRes.ok) {
      throw new Error('카카오 인증에 실패했어요. 다시 시도해주세요.')
    }

    const kakaoUser = await kakaoRes.json()
    const kakaoId   = String(kakaoUser.id)
    const nickname  = kakaoUser.kakao_account?.profile?.nickname ?? '고객'
    const avatarUrl = kakaoUser.kakao_account?.profile?.profile_image_url ?? null

    // ── 2. Supabase Admin 클라이언트 (service key 필요) ───────────────
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const email    = `kakao_${kakaoId}@mompill.app`
    const metadata = { kakao_id: kakaoId, nickname, avatar_url: avatarUrl }

    // ── 3. profiles.kakao_id로 기존 유저 조회 (listUsers 대신 O(1)) ──
    // listUsers(perPage:1000) 방식은 유저 증가 시 누락 위험이 있어 교체
    let userId: string | null = null

    const { data: existingProfile } = await supabase
      .from('profiles')
      .select('id')
      .eq('kakao_id', kakaoId)
      .maybeSingle()

    if (existingProfile) {
      userId = existingProfile.id as string
      await supabase.auth.admin.updateUserById(userId, { user_metadata: metadata })
    } else {
      // 신규 유저 생성
      const { data: created, error: createErr } = await supabase.auth.admin.createUser({
        email,
        email_confirm: true,
        user_metadata: metadata,
      })

      if (createErr) {
        // 드물게 profiles 없이 auth.users만 있는 경우 — email로 재탐색
        if (!createErr.message.includes('already been registered')) throw createErr

        const { data: { users } } = await supabase.auth.admin.listUsers({
          page: 1,
          perPage: 50,
        })
        const existing = users.find((u) => u.email === email)
        if (!existing) throw new Error('유저 정보를 확인할 수 없어요. 다시 시도해주세요.')
        userId = existing.id
        await supabase.auth.admin.updateUserById(userId, { user_metadata: metadata })
      } else {
        userId = created.user!.id
      }
    }

    // ── 4. profiles upsert — kakao_id 포함 저장 ─────────────────────
    await supabase.from('profiles').upsert({
      id: userId,
      kakao_id: kakaoId,
      kakao_nickname: nickname,
      avatar_url: avatarUrl,
    })

    // ── 5. Magic link 생성 → OTP 토큰 추출 → 앱에 반환 ──────────────
    const { data: linkData, error: linkErr } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email,
    })
    if (linkErr) throw linkErr

    const url   = new URL(linkData.properties.action_link)
    const token = url.searchParams.get('token')
    if (!token) throw new Error('토큰 생성에 실패했어요. 다시 시도해주세요.')

    return new Response(
      JSON.stringify({ email, token }),
      { headers: { ...CORS, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : '잠깐 문제가 생겼어요. 다시 시도해주세요.'
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 400, headers: { ...CORS, 'Content-Type': 'application/json' } },
    )
  }
})
