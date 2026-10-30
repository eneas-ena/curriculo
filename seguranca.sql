-- ============================================================
-- REDE DE CRIANÇAS · Igreja Vidas — Segurança do banco (versão 1)
--
-- O que muda:
--  * Acabam os PINs. O app passa a pedir e-mail e senha.
--  * Administrador = login do Bispo (função eh_dono, criada pelo
--    script das Despesas): gera, edita, aprova e sobe imagens.
--  * Conta comum da equipe = só VÊ e IMPRIME, todas as turmas.
--  * Sem login, ninguém lê nem altera nada.
--
-- ANTES DE RODAR: crie a conta da equipe em
--   Authentication → Users → Add user → Create new user
--     e-mail: rede-criancas@igrejavidas.app
--     senha:  a que o senhor quiser passar para a equipe
--   marcando "Auto Confirm User".
--
-- DEPOIS: cole tudo no SQL Editor do Supabase e clique em RUN.
-- Pode rodar de novo sem problema (por exemplo, se recriar a conta).
-- As lições, materiais e imagens atuais são mantidos.
-- ============================================================

-- 1) Quem é quem (esta tabela não pode ser lida nem alterada pelo app)
create table if not exists curriculo.acesso (
  user_id uuid primary key references auth.users(id) on delete cascade,
  papel text not null check (papel in ('leitor'))
);
alter table curriculo.acesso enable row level security;
revoke all on curriculo.acesso from anon, authenticated;

delete from curriculo.acesso;
insert into curriculo.acesso (user_id, papel)
  select id, 'leitor' from auth.users where lower(email) = 'rede-criancas@igrejavidas.app';

-- Devolve o papel de quem está logado: 'admin', 'leitor' ou nada
create or replace function curriculo.cur_papel()
returns text
language sql stable security definer
set search_path = ''
as $$
  select case
    when coalesce(public.eh_dono(), false) then 'admin'
    else (select a.papel from curriculo.acesso a where a.user_id = auth.uid())
  end
$$;
revoke all on function curriculo.cur_papel() from public;
grant execute on function curriculo.cur_papel() to anon, authenticated;
grant usage on schema curriculo to anon, authenticated;

-- 2) Todas as tabelas do app: apaga as regras antigas e cria as novas
do $$
declare t record; p record;
begin
  for t in select tablename from pg_tables
           where schemaname = 'curriculo' and tablename <> 'acesso'
  loop
    execute format('alter table curriculo.%I enable row level security', t.tablename);
    for p in select policyname from pg_policies
             where schemaname = 'curriculo' and tablename = t.tablename
    loop
      execute format('drop policy %I on curriculo.%I', p.policyname, t.tablename);
    end loop;
    execute format('revoke all on curriculo.%I from anon, authenticated', t.tablename);
    execute format('grant select, insert, update, delete on curriculo.%I to authenticated', t.tablename);
    -- equipe e administrador LEEM
    execute format($f$create policy "rc_ler" on curriculo.%I for select to authenticated
                     using (curriculo.cur_papel() in ('admin','leitor'))$f$, t.tablename);
    -- só o administrador GRAVA
    execute format($f$create policy "rc_admin" on curriculo.%I for all to authenticated
                     using (public.eh_dono()) with check (public.eh_dono())$f$, t.tablename);
  end loop;

  -- Visões (ex.: v_progresso_faixa) passam a obedecer às mesmas regras
  for t in select viewname from pg_views where schemaname = 'curriculo'
  loop
    execute format('alter view curriculo.%I set (security_invoker = true)', t.viewname);
    execute format('revoke all on curriculo.%I from anon, authenticated', t.viewname);
    execute format('grant select on curriculo.%I to authenticated', t.viewname);
  end loop;
end $$;

grant usage, select on all sequences in schema curriculo to authenticated;
revoke all on all sequences in schema curriculo from anon;

-- 3) Imagens (pasta "rede-criancas" do Storage): todos continuam VENDO
--    as imagens nas lições; só o administrador ENVIA, TROCA ou APAGA.
drop policy if exists "rc_img_admin"        on storage.objects;
drop policy if exists "rc_img_trava_enviar" on storage.objects;
drop policy if exists "rc_img_trava_trocar" on storage.objects;
drop policy if exists "rc_img_trava_apagar" on storage.objects;

create policy "rc_img_admin" on storage.objects for all to authenticated
  using (bucket_id = 'rede-criancas' and public.eh_dono())
  with check (bucket_id = 'rede-criancas' and public.eh_dono());

-- Travas que valem por cima de qualquer regra antiga dessa pasta
create policy "rc_img_trava_enviar" on storage.objects as restrictive for insert to public
  with check (bucket_id <> 'rede-criancas' or public.eh_dono());
create policy "rc_img_trava_trocar" on storage.objects as restrictive for update to public
  using (bucket_id <> 'rede-criancas' or public.eh_dono())
  with check (bucket_id <> 'rede-criancas' or public.eh_dono());
create policy "rc_img_trava_apagar" on storage.objects as restrictive for delete to public
  using (bucket_id <> 'rede-criancas' or public.eh_dono());

-- 4) Conferência: deve mostrar 1 linha, a conta da equipe como "leitor".
--    Se vier vazio, a conta ainda não foi criada (veja o início do script).
select u.email, a.papel
from curriculo.acesso a join auth.users u on u.id = a.user_id;
