UPDATE "public".o_stage SET "Ten o" = '5' WHERE id = 63
UPDATE "public".o_stage SET "Ten o" = '7' WHERE id = 35    

INSERT INTO public.khu (ma_khu, ten_khu, toa_do)
SELECT
  gen_random_uuid(),
  s.ma_khu,
  ST_SetSRID(ST_Multi(s.geom), 4326)::geometry(MultiPolygon,4326)
FROM public.khu_stage s

INSERT INTO public.hang (ma_hang, ten_hang, ma_khu, toa_do)
SELECT
  gen_random_uuid(),
  s."Ma hang",
  s."Ma khu",
  ST_SetSRID(ST_Multi(s.geom), 4326)::geometry(MultiPolygon,4326)
FROM public.hang_stage s

INSERT INTO public.o (id, dia_chi, ten_o, ma_hang, ma_khu, toa_do)
SELECT
  gen_random_uuid(),
  (k.ten_khu || '-' || h.ten_hang || '-' || s."Ten o") AS dia_chi,
  s."Ten o" AS ten_o,
  h.ma_hang,
  k.ma_khu,
  ST_SetSRID(ST_Multi(s.geom), 4326)::geometry(MultiPolygon,4326)
FROM public.o_stage s, "public".khu k, "public".hang h
WHERE s."Ma khu" = k.ten_khu 
AND s."Ma hang" = h.ten_hang
AND k.ma_khu = h.ma_khu

