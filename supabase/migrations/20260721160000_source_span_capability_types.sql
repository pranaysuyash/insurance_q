-- Extend source-span vocabulary for source-bearing CIR nodes.
-- Image-only figures remain page-artifact/layout evidence because source_spans
-- require text and geometry; no generated caption is inserted as proof.

alter table public.source_spans
  drop constraint if exists source_spans_span_type_check;

alter table public.source_spans
  add constraint source_spans_span_type_check
  check (span_type in (
    'text_block','sentence','paragraph','heading','line','word',
    'table_cell','table','formula','form_field','caption','annotation',
    'header','footer','list_item','other'
  ));

comment on column public.source_spans.span_type is
  'Source-bearing CIR node type. Image-only figures remain page-artifact evidence.';
