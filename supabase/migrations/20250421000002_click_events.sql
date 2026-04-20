-- click_events: 쿠팡 링크 클릭 이력 — 전환율 측정 및 파트너스 정산 검증용
CREATE TABLE public.click_events (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scan_id      uuid        REFERENCES public.scans(id) ON DELETE SET NULL,
  product_name text        NOT NULL,
  clicked_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.click_events ENABLE ROW LEVEL SECURITY;

-- 본인 클릭 이력만 조회 가능
CREATE POLICY "Users can view own click events"
  ON public.click_events FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- 본인 클릭만 기록 가능
CREATE POLICY "Users can insert own click events"
  ON public.click_events FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_click_events_user_id   ON public.click_events(user_id);
CREATE INDEX idx_click_events_clicked_at ON public.click_events(clicked_at DESC);
