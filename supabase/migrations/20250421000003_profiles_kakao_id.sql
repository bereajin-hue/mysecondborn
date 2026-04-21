-- profiles에 kakao_id 컬럼 추가 — Edge Function에서 listUsers 대신 O(1) 조회를 위해
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kakao_id text;

CREATE INDEX IF NOT EXISTS idx_profiles_kakao_id ON public.profiles(kakao_id);
