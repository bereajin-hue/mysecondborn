-- ============================================================
-- MomPill 초기 스키마
-- ============================================================

-- profiles: auth.users와 1:1 연결, 카카오 닉네임·프로필 저장
CREATE TABLE public.profiles (
  id         uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  kakao_nickname text,
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- products: Gemini 분석 결과 캐싱 — 동일 제품 재분석을 막아 API 비용 절감
CREATE TABLE public.products (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name               text        NOT NULL,
  brand              text,
  ingredients        jsonb       NOT NULL DEFAULT '[]'::jsonb,
  image_url          text,
  coupang_search_url text,
  hit_count          integer     NOT NULL DEFAULT 0,
  created_at         timestamptz NOT NULL DEFAULT now()
);

-- scans: 유저별 촬영·분석 이력, gemini_response는 원본 JSON 그대로 보존
CREATE TABLE public.scans (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id       uuid        REFERENCES public.products(id) ON DELETE SET NULL,
  raw_image_url    text,
  gemini_response  jsonb,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- cabinet: 유저가 저장한 영양제 목록
CREATE TABLE public.cabinet (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id uuid        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  note       text,
  added_at   timestamptz NOT NULL DEFAULT now()
);

-- usage_limits: 유저당 하루 Gemini 호출 횟수 추적 (복합 PK로 중복 방지)
CREATE TABLE public.usage_limits (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date    date NOT NULL DEFAULT CURRENT_DATE,
  count   integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, date)
);

-- ============================================================
-- 인덱스: 자주 쓰이는 WHERE 조건에 추가
-- ============================================================
CREATE INDEX idx_scans_user_id    ON public.scans(user_id);
CREATE INDEX idx_scans_created_at ON public.scans(created_at DESC);
CREATE INDEX idx_scans_product_id ON public.scans(product_id);
CREATE INDEX idx_cabinet_user_id  ON public.cabinet(user_id);
-- 이름 검색으로 캐시 히트를 높이기 위해 trigram 인덱스 사용
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_products_name_trgm ON public.products USING gin(name gin_trgm_ops);

-- ============================================================
-- 신규 유저 프로필 자동 생성 트리거
-- (카카오 로그인 직후 profiles 행이 없어 404 나는 상황 방지)
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, kakao_nickname, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'nickname',
    NEW.raw_user_meta_data ->> 'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
