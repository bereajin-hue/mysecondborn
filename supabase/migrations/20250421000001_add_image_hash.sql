-- image_hash: 동일 사진 재분석 방지용 — 해시 일치 시 Gemini 호출 없이 결과 재사용
ALTER TABLE public.scans ADD COLUMN IF NOT EXISTS image_hash text;

CREATE INDEX IF NOT EXISTS idx_scans_image_hash
  ON public.scans(image_hash)
  WHERE image_hash IS NOT NULL;
