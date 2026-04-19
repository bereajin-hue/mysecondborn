-- ============================================================
-- MomPill RLS 정책
-- 원칙: 유저는 자신의 데이터만, products는 전체 읽기, 쓰기는 서비스 키 전용
-- ============================================================

ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scans        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cabinet      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_limits ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- profiles: 본인 행만 접근
-- ============================================================
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- products: 읽기는 인증된 모든 유저 허용 (캐시 공유)
-- 쓰기 정책 없음 → 서비스 키(Edge Function)만 INSERT/UPDATE 가능
-- ============================================================
CREATE POLICY "products_select_authenticated"
  ON public.products FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================
-- scans: 본인 행만
-- ============================================================
CREATE POLICY "scans_select_own"
  ON public.scans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "scans_insert_own"
  ON public.scans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "scans_delete_own"
  ON public.scans FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- cabinet: 본인 행만 CRUD
-- ============================================================
CREATE POLICY "cabinet_select_own"
  ON public.cabinet FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "cabinet_insert_own"
  ON public.cabinet FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cabinet_update_own"
  ON public.cabinet FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cabinet_delete_own"
  ON public.cabinet FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- usage_limits: 읽기는 본인만
-- INSERT/UPDATE는 Edge Function이 service key로만 처리
-- (클라이언트에서 직접 count를 조작하지 못하도록 쓰기 정책 없음)
-- ============================================================
CREATE POLICY "usage_limits_select_own"
  ON public.usage_limits FOR SELECT
  USING (auth.uid() = user_id);
