// Supabase Edge Function: Storage 이미지 → Gemini 분석 → scans/products 업데이트
// Deno 런타임 — Node.js 문법 사용 금지

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_MODEL = 'gemini-2.5-flash'
// 규칙 3번: 재시도 1s → 3s → 9s
const RETRY_DELAYS = [1000, 3000, 9000]

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { scan_id } = await req.json()
    if (!scan_id) throw new Error('scan_id가 없습니다')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )
    const geminiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiKey) throw new Error('GEMINI_API_KEY 환경변수가 설정되지 않았습니다')

    // ── 1. scan 레코드 조회 ───────────────────────────────────────
    const { data: scan, error: scanErr } = await supabase
      .from('scans')
      .select('id, user_id, raw_image_url')
      .eq('id', scan_id)
      .single()
    if (scanErr || !scan) throw new Error('스캔 기록을 찾을 수 없어요')
    if (!scan.raw_image_url) throw new Error('이미지 URL이 없습니다')

    // ── 2. 프롬프트 로드 (CLI 배포 시 파일, 대시보드 배포 시 인라인 상수 사용) ──
    let prompt: string
    try {
      prompt = await Deno.readTextFile('./prompt.md')
    } catch {
      prompt = `## 역할
당신은 한국 건강기능식품 성분 분석 전문가입니다.
사용자가 제공한 영양제 제품 이미지를 분석해 구매 결정에 필요한 정보를 JSON으로 반환합니다.

## 절대 규칙
1. JSON만 출력: 설명, 인사말, 마크다운 코드블록 일체 금지. 순수 JSON 텍스트만.
2. 의료 표현 금지: "치료", "예방", "치유", "완치", "처방", "의약품" 사용 금지.
3. 추측 금지: 이미지에서 읽을 수 없는 정보는 반드시 null 처리.
4. 한국어 응답: 모든 텍스트 필드는 한국어로 작성.
5. 영양제가 아닌 이미지: {"error":"영양제 제품이 아닙니다"} 만 반환.

## 출력 형식 (영양제인 경우)
{"product_name":"제품 정확 명칭","brand":"브랜드명 또는 null","main_ingredients":[{"name":"성분명","amount":"함량(단위포함)","daily_percent":"일일권장량% 또는 null"}],"category":"비타민|미네랄|프로바이오틱스|오메가3|기타","key_benefits":["기능성1","기능성2"],"warnings":["주의사항"],"target_age":"추천연령대 또는 null","confidence":0.0~1.0,"readable_summary":"70대 어르신도 이해할 3줄 이내 설명"}

confidence 기준: 0.9~1.0=모든정보확인, 0.7~0.8=일부흐릿, 0.5~0.6=제품명만확인, 0.5미만=product_name에 "(정확도 낮음)" 추가`
    }

    // ── 3. 이미지 다운로드 → Base64 변환 ─────────────────────────
    const imgRes = await fetch(scan.raw_image_url)
    if (!imgRes.ok) throw new Error('이미지를 가져올 수 없어요')
    const imgBuffer = await imgRes.arrayBuffer()
    const imgBytes = new Uint8Array(imgBuffer)

    // 스택 오버플로 방지를 위해 청크 단위로 Base64 인코딩
    let binary = ''
    for (let i = 0; i < imgBytes.length; i += 8192) {
      binary += String.fromCharCode(...imgBytes.subarray(i, Math.min(i + 8192, imgBytes.length)))
    }
    const base64Image = btoa(binary)

    // ── 4. Gemini 호출 (규칙 3번: 재시도 3회) ────────────────────
    let lastError: Error | null = null
    let geminiData: Record<string, unknown> | null = null

    for (let attempt = 0; attempt < RETRY_DELAYS.length; attempt++) {
      try {
        const geminiRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${geminiKey}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{
                parts: [
                  { text: prompt },
                  { inline_data: { mime_type: 'image/jpeg', data: base64Image } },
                ],
              }],
              generationConfig: { temperature: 0.1 },
            }),
            signal: AbortSignal.timeout(20000),
          },
        )

        if (!geminiRes.ok) {
          throw new Error(`Gemini 응답 오류: ${geminiRes.status}`)
        }

        const geminiJson = await geminiRes.json()
        const text = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text?.trim()
        if (!text) throw new Error('분석 결과가 비어있습니다')

        // Gemini가 간혹 마크다운 코드블록을 포함하는 경우 방어 처리
        const cleaned = text
          .replace(/```json\s*/gm, '')
          .replace(/```\s*/gm, '')
          .trim()

        geminiData = JSON.parse(cleaned)
        break
      } catch (e) {
        lastError = e as Error
        if (attempt < RETRY_DELAYS.length - 1) {
          await new Promise((r) => setTimeout(r, RETRY_DELAYS[attempt]))
        }
      }
    }

    // 재시도 소진 — 결과 화면에 재시도 안내 저장
    if (!geminiData) {
      await supabase
        .from('scans')
        .update({ gemini_response: { error: '분석이 잘 안 됐어요. 다시 찍어볼까요?' } })
        .eq('id', scan_id)
      return new Response(
        JSON.stringify({ error: lastError?.message }),
        { status: 200, headers: { ...CORS, 'Content-Type': 'application/json' } },
      )
    }

    // ── 5. 영양제 아닌 이미지 / 에러 응답 바로 저장 ──────────────
    if (geminiData.error) {
      await supabase.from('scans').update({ gemini_response: geminiData }).eq('id', scan_id)
      return new Response(
        JSON.stringify({ ok: true }),
        { headers: { ...CORS, 'Content-Type': 'application/json' } },
      )
    }

    // ── 6. products 테이블 upsert (캐시 히트 시 hit_count++) ──────
    let productId: string | null = null
    const productName = geminiData.product_name as string | null
    const brand = (geminiData.brand as string | null) ?? ''

    if (productName) {
      const { data: existing } = await supabase
        .from('products')
        .select('id, hit_count')
        .eq('name', productName)
        .eq('brand', brand)
        .maybeSingle()

      if (existing) {
        productId = existing.id as string
        await supabase
          .from('products')
          .update({ hit_count: (existing.hit_count as number) + 1 })
          .eq('id', productId)
      } else {
        const { data: inserted } = await supabase
          .from('products')
          .insert({
            name: productName,
            brand: brand || null,
            ingredients: geminiData.main_ingredients ?? [],
            image_url: scan.raw_image_url,
            coupang_search_url: null, // Day 4에서 쿠팡 파트너스 API 연동 후 채울 예정
          })
          .select('id')
          .single()
        productId = (inserted?.id as string) ?? null
      }
    }

    // ── 7. scans 업데이트 → ResultScreen 실시간 구독이 즉시 감지 ─
    await supabase
      .from('scans')
      .update({ gemini_response: geminiData, product_id: productId })
      .eq('id', scan_id)

    return new Response(
      JSON.stringify({ ok: true, product_id: productId }),
      { headers: { ...CORS, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : '잠깐 문제가 생겼어요'
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...CORS, 'Content-Type': 'application/json' } },
    )
  }
})
