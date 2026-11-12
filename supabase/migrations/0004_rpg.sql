-- Forja · 0004 · Etapa 3: personagem, inventário, títulos, conquistas, chefes e modos de dificuldade
--
-- Pode ser aplicada num banco que já tem 0001–0003 e usuários com dados.
-- Também pode ser rodada de novo sem estragar nada (tudo usa "if not exists" / "on conflict").
-- Regra geral continua a mesma: o app só LÊ; tudo que dá XP, item ou vitória passa por funções do servidor.

-- ════════════════════════════════════════════════════════════════════════════
-- 1. Tabelas
-- ════════════════════════════════════════════════════════════════════════════

alter table public.profiles add column if not exists avatar jsonb not null default '{}'::jsonb;
alter table public.profiles add column if not exists active_title text;
alter table public.profiles add column if not exists mode_cooldown_until date;

-- Histórico de regras (modo e meta mínima). Cada dia é julgado pelas regras que valiam naquele dia,
-- então mudar o modo ou a meta não reescreve o passado.
create table if not exists public.rules_history (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  started_on  date not null,
  mode        text not null check (mode in ('normal','desafio','extremo')),
  min_daily   smallint not null check (min_daily between 1 and 10),
  reason      text not null default 'escolha' check (reason in ('inicial','escolha','rebaixado')),
  created_at  timestamptz not null default now()
);
create index if not exists rules_history_user_idx on public.rules_history (user_id, started_on desc, id desc);

-- Ajustes de meta feitos pela pessoa (alimenta a conquista "Ajuste consciente" e, no futuro, a IA)
create table if not exists public.habit_adjustments (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  habit_id    uuid not null references public.user_habits(id) on delete cascade,
  old_target  integer not null,
  new_target  integer not null,
  paused      boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists habit_adjustments_user_idx on public.habit_adjustments (user_id);

-- Equipamentos e títulos
create table if not exists public.item_catalog (
  id            text primary key,
  kind          text not null check (kind in ('equipamento','titulo')),
  slot          text check (slot in ('cabeca','corpo','capa','arma','amuleto','moldura')),
  name          text not null,
  description   text not null,
  rarity        text not null check (rarity in ('comum','raro','epico','lendario')),
  unlock_type   text not null check (unlock_type in ('inicial','nivel','conquista','chefe')),
  unlock_level  integer,
  unlock_ref    text,
  sort          smallint not null default 0,
  check ((kind = 'equipamento') = (slot is not null)),
  check ((unlock_type = 'nivel') = (unlock_level is not null)),
  check ((unlock_type in ('conquista','chefe')) = (unlock_ref is not null))
);

create table if not exists public.user_items (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  item_id      text not null references public.item_catalog(id),
  source       text not null,
  unlocked_at  timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- Conquistas
create table if not exists public.achievement_catalog (
  id          text primary key,
  category    text not null check (category in ('missoes','sequencia','programa','nivel','atributos','habitos','chefes','modos')),
  name        text not null,
  description text not null,
  rarity      text not null check (rarity in ('comum','raro','epico','lendario')),
  metric      text not null,
  threshold   integer not null check (threshold > 0),
  xp          integer not null default 0 check (xp >= 0),
  attr        text not null check (attr in ('disciplina','foco','vitalidade','conhecimento','determinacao')),
  hidden      boolean not null default false,
  sort        smallint not null default 0
);

create table if not exists public.user_achievements (
  user_id         uuid not null references public.profiles(id) on delete cascade,
  achievement_id  text not null references public.achievement_catalog(id),
  unlocked_at     timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

-- Chefes
create table if not exists public.boss_catalog (
  id                  text primary key,
  name                text not null,
  epithet             text not null,
  story               text not null,
  objective           text not null,
  difficulty          smallint not null check (difficulty between 1 and 5),
  hit_rule            text not null check (hit_rule in ('dimensao','meta_diaria','dia_perfeito')),
  dimension           text check (dimension in ('fisica','mental','intelectual','produtividade','digital','autocuidado')),
  hp                  smallint not null check (hp > 0),
  window_days         smallint not null,
  unlock_day          smallint not null default 1,
  requires_victories  smallint not null default 0,
  xp_reward           integer not null,
  attr_primary        text not null,
  attr_secondary      text not null,
  sort                smallint not null,
  check ((hit_rule = 'dimensao') = (dimension is not null)),
  check (window_days >= hp)
);

create table if not exists public.user_bosses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  boss_id      text not null references public.boss_catalog(id),
  started_on   date not null,
  deadline     date not null,
  hp           integer not null,
  hits         integer not null default 0,
  heals        integer not null default 0,
  rematch      boolean not null default false,
  status       text not null default 'ativo' check (status in ('ativo','vencido','recuou','desistiu')),
  finished_at  timestamptz,
  created_at   timestamptz not null default now(),
  check (deadline >= started_on)
);
create unique index if not exists user_bosses_one_active on public.user_bosses (user_id) where status = 'ativo';
create index if not exists user_bosses_user_idx on public.user_bosses (user_id, boss_id);

-- Avisos que o app mostra uma vez (conquista, item, nível, vitória, recuo, rebaixamento)
create table if not exists public.user_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('nivel','conquista','item','chefe_vencido','chefe_recuou','modo_rebaixado')),
  ref         text not null,
  seen        boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (user_id, kind, ref)
);
create index if not exists user_events_unseen_idx on public.user_events (user_id) where not seen;

-- Histórico de XP: novas origens e referência (conquista ou batalha)
alter table public.xp_ledger add column if not exists ref text;
alter table public.xp_ledger drop constraint if exists xp_ledger_source_check;
alter table public.xp_ledger add constraint xp_ledger_source_check
  check (source in ('missao','meta_diaria','retorno','marco','conquista','chefe'));
drop index if exists public.xp_ledger_bonus_once;
create unique index if not exists xp_ledger_daily_bonus_once on public.xp_ledger (user_id, source, day)
  where source in ('meta_diaria','retorno');
create unique index if not exists xp_ledger_ref_once on public.xp_ledger (user_id, source, ref) where ref is not null;

-- ── Segurança das novas tabelas ─────────────────────────────────────────────
alter table public.rules_history        enable row level security;
alter table public.habit_adjustments    enable row level security;
alter table public.item_catalog         enable row level security;
alter table public.user_items           enable row level security;
alter table public.achievement_catalog  enable row level security;
alter table public.user_achievements    enable row level security;
alter table public.boss_catalog         enable row level security;
alter table public.user_bosses          enable row level security;
alter table public.user_events          enable row level security;

drop policy if exists "ler as próprias regras" on public.rules_history;
create policy "ler as próprias regras" on public.rules_history for select using (user_id = auth.uid());
drop policy if exists "ler os próprios ajustes" on public.habit_adjustments;
create policy "ler os próprios ajustes" on public.habit_adjustments for select using (user_id = auth.uid());
drop policy if exists "catálogo de itens" on public.item_catalog;
create policy "catálogo de itens" on public.item_catalog for select using (auth.uid() is not null);
drop policy if exists "ler os próprios itens" on public.user_items;
create policy "ler os próprios itens" on public.user_items for select using (user_id = auth.uid());
drop policy if exists "catálogo de conquistas" on public.achievement_catalog;
create policy "catálogo de conquistas" on public.achievement_catalog for select using (auth.uid() is not null);
drop policy if exists "ler as próprias conquistas" on public.user_achievements;
create policy "ler as próprias conquistas" on public.user_achievements for select using (user_id = auth.uid());
drop policy if exists "catálogo de chefes" on public.boss_catalog;
create policy "catálogo de chefes" on public.boss_catalog for select using (auth.uid() is not null);
drop policy if exists "ler as próprias batalhas" on public.user_bosses;
create policy "ler as próprias batalhas" on public.user_bosses for select using (user_id = auth.uid());
drop policy if exists "ler os próprios avisos" on public.user_events;
create policy "ler os próprios avisos" on public.user_events for select using (user_id = auth.uid());

-- ════════════════════════════════════════════════════════════════════════════
-- 2. Catálogos
-- ════════════════════════════════════════════════════════════════════════════

insert into public.boss_catalog
  (id, name, epithet, story, objective, difficulty, hit_rule, dimension, hp, window_days, unlock_day, requires_victories, xp_reward, attr_primary, attr_secondary, sort)
values
  ('tempestade', 'A Tempestade Interna', 'Guardiã da Sobrecarga',
   'Ela se forma quando tudo acontece ao mesmo tempo dentro da sua cabeça. Não se vence com força, e sim com pausas. Cada momento de calma tira um pouco do vento dela.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Saúde mental.',
   1, 'dimensao', 'mental', 5, 7, 2, 0, 100, 'foco', 'vitalidade', 1),
  ('adiador', 'O Adiador', 'Chefe da Procrastinação',
   'Ele mora no "só mais cinco minutos". Cada tarefa adiada vira um grão na ampulheta dele, e a areia nunca cai. Golpes de execução fazem o vidro rachar.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Disciplina e produtividade.',
   1, 'dimensao', 'produtividade', 5, 7, 2, 0, 100, 'disciplina', 'determinacao', 2),
  ('hidra', 'A Hidra das Notificações', 'Guardiã das Distrações',
   'Corte uma cabeça e outra pisca na tela. A Hidra se alimenta da sua atenção em pedaços e só enfraquece com períodos de foco de verdade.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Saúde digital.',
   2, 'dimensao', 'digital', 7, 10, 8, 0, 160, 'foco', 'disciplina', 3),
  ('nevoa', 'A Névoa do Esquecimento', 'Guardiã do Esquecimento',
   'Ela apaga devagar o que você não revisita. Páginas viram fumaça e ideias perdem a forma. Cada sessão de leitura ou estudo abre uma clareira.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Desenvolvimento intelectual.',
   2, 'dimensao', 'intelectual', 7, 10, 8, 0, 160, 'conhecimento', 'foco', 4),
  ('sentinela', 'A Sentinela de Pedra', 'Sentinela do Desconforto',
   'Ela guarda a porta entre o confortável e o possível. Não ataca: só espera que você desista de passar. Cada dia de movimento racha a pedra.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Saúde física.',
   3, 'dimensao', 'fisica', 10, 14, 15, 0, 240, 'vitalidade', 'determinacao', 5),
  ('errante', 'O Errante', 'Mestre da Inconsistência',
   'Ele nunca está no mesmo lugar dois dias seguidos e quer que você também não esteja. Começa forte, some, volta. Só a constância o prende.',
   'Golpe: cada dia em que você cumprir a sua meta do dia.',
   3, 'meta_diaria', null, 12, 16, 22, 0, 300, 'disciplina', 'determinacao', 6),
  ('juiz', 'O Juiz da Bigorna', 'Desafio da Disciplina',
   'O último guardião da Forja. Não aceita meio esforço: só reconhece dias em que todo o plano foi cumprido. Vencê-lo é mostrar que a disciplina virou rotina.',
   'Golpe: cada dia em que você concluir todas as missões diárias do seu plano.',
   5, 'dia_perfeito', null, 14, 20, 34, 3, 450, 'determinacao', 'disciplina', 7)
on conflict (id) do update set
  name = excluded.name, epithet = excluded.epithet, story = excluded.story, objective = excluded.objective,
  difficulty = excluded.difficulty, hit_rule = excluded.hit_rule, dimension = excluded.dimension, hp = excluded.hp,
  window_days = excluded.window_days, unlock_day = excluded.unlock_day, requires_victories = excluded.requires_victories,
  xp_reward = excluded.xp_reward, attr_primary = excluded.attr_primary, attr_secondary = excluded.attr_secondary, sort = excluded.sort;

insert into public.achievement_catalog (id, category, name, description, rarity, metric, threshold, xp, attr, hidden, sort) values
  -- Missões
  ('m_1',   'missoes', 'Primeira faísca',  'Conclua sua primeira missão.',  'comum',    'missoes', 1,   20,  'disciplina',   false, 1),
  ('m_25',  'missoes', 'Ritmo de forja',   'Conclua 25 missões.',           'comum',    'missoes', 25,  40,  'disciplina',   false, 2),
  ('m_100', 'missoes', 'Cem golpes',       'Conclua 100 missões.',          'raro',     'missoes', 100, 100, 'determinacao', false, 3),
  ('m_300', 'missoes', 'Mão calejada',     'Conclua 300 missões.',          'epico',    'missoes', 300, 180, 'determinacao', false, 4),
  ('m_750', 'missoes', 'Incansável',       'Conclua 750 missões.',          'lendario', 'missoes', 750, 300, 'determinacao', false, 5),
  -- Sequência (marcos)
  ('s_7',   'sequencia', 'Uma semana inteira', 'Cumpra a meta do dia por 7 dias seguidos.',   'comum',    'melhor_sequencia', 7,   40,  'disciplina', false, 10),
  ('s_14',  'sequencia', 'Duas semanas firmes','Cumpra a meta do dia por 14 dias seguidos.',  'raro',     'melhor_sequencia', 14,  60,  'disciplina', false, 11),
  ('s_21',  'sequencia', 'Vinte e um dias',    'Cumpra a meta do dia por 21 dias seguidos.',  'raro',     'melhor_sequencia', 21,  80,  'disciplina', false, 12),
  ('s_33',  'sequencia', 'Trinta e três',      'Cumpra a meta do dia por 33 dias seguidos.',  'epico',    'melhor_sequencia', 33,  110, 'disciplina', false, 13),
  ('s_45',  'sequencia', 'Quarenta e cinco',   'Cumpra a meta do dia por 45 dias seguidos.',  'epico',    'melhor_sequencia', 45,  140, 'disciplina', false, 14),
  ('s_66',  'sequencia', 'A marca dos 66',     'Cumpra a meta do dia por 66 dias seguidos.',  'lendario', 'melhor_sequencia', 66,  200, 'disciplina', false, 15),
  ('s_90',  'sequencia', 'Noventa dias',       'Cumpra a meta do dia por 90 dias seguidos.',  'lendario', 'melhor_sequencia', 90,  250, 'disciplina', false, 16),
  ('s_132', 'sequencia', 'O dobro do caminho', 'Cumpra a meta do dia por 132 dias seguidos.', 'lendario', 'melhor_sequencia', 132, 320, 'disciplina', false, 17),
  -- Programa (dias ativos, não precisam ser seguidos)
  ('p_7',  'programa', 'Adaptação',         'Fique ativo em 7 dias, seguidos ou não.',  'comum',    'dias_ativos', 7,  30,  'determinacao', false, 20),
  ('p_21', 'programa', 'Construção',        'Fique ativo em 21 dias, seguidos ou não.', 'raro',     'dias_ativos', 21, 60,  'determinacao', false, 21),
  ('p_33', 'programa', 'Consolidação',      'Fique ativo em 33 dias, seguidos ou não.', 'raro',     'dias_ativos', 33, 90,  'determinacao', false, 22),
  ('p_45', 'programa', 'Evolução',          'Fique ativo em 45 dias, seguidos ou não.', 'epico',    'dias_ativos', 45, 120, 'determinacao', false, 23),
  ('p_66', 'programa', 'Programa completo', 'Fique ativo em 66 dias, seguidos ou não.', 'lendario', 'dias_ativos', 66, 220, 'determinacao', false, 24),
  -- Nível (sem XP, para não alimentar a si mesmo)
  ('n_5',  'nivel', 'Primeiro brilho', 'Alcance o nível 5.',  'comum',    'nivel', 5,  0, 'determinacao', false, 30),
  ('n_10', 'nivel', 'Aço temperado',   'Alcance o nível 10.', 'raro',     'nivel', 10, 0, 'determinacao', false, 31),
  ('n_15', 'nivel', 'Têmpera dupla',   'Alcance o nível 15.', 'epico',    'nivel', 15, 0, 'determinacao', false, 32),
  ('n_20', 'nivel', 'Liga rara',       'Alcance o nível 20.', 'epico',    'nivel', 20, 0, 'determinacao', false, 33),
  ('n_30', 'nivel', 'Metal lendário',  'Alcance o nível 30.', 'lendario', 'nivel', 30, 0, 'determinacao', false, 34),
  -- Atributos
  ('a_disciplina',   'atributos', 'Vontade de ferro', 'Leve Disciplina ao nível 5.',          'raro',  'attr_disciplina',   5, 50,  'disciplina',   false, 40),
  ('a_foco',         'atributos', 'Mente afiada',     'Leve Foco ao nível 5.',                'raro',  'attr_foco',         5, 50,  'foco',         false, 41),
  ('a_vitalidade',   'atributos', 'Corpo desperto',   'Leve Vitalidade ao nível 5.',          'raro',  'attr_vitalidade',   5, 50,  'vitalidade',   false, 42),
  ('a_conhecimento', 'atributos', 'Sede de saber',    'Leve Conhecimento ao nível 5.',        'raro',  'attr_conhecimento', 5, 50,  'conhecimento', false, 43),
  ('a_determinacao', 'atributos', 'Coração firme',    'Leve Determinação ao nível 5.',        'raro',  'attr_determinacao', 5, 50,  'determinacao', false, 44),
  ('a_equilibrio',   'atributos', 'Equilíbrio',       'Leve os cinco atributos ao nível 4.',  'epico', 'attr_min',          4, 120, 'determinacao', false, 45),
  -- Hábitos
  ('h_areas',    'habitos', 'Seis frentes',      'Conclua missões nas seis áreas.',                                   'raro',  'areas',         6,  60, 'conhecimento', false, 50),
  ('h_revisao',  'habitos', 'Olhar para trás',   'Conclua 4 revisões da semana.',                                     'comum', 'revisoes',      4,  50, 'disciplina',   false, 51),
  ('h_especial', 'habitos', 'Além da meta',      'Conclua 3 missões especiais.',                                      'raro',  'especiais',     3,  60, 'determinacao', false, 52),
  ('h_surpresa', 'habitos', 'Curiosidade',       'Conclua 10 missões surpresa.',                                      'comum', 'surpresas',     10, 50, 'conhecimento', false, 53),
  ('h_evolucao', 'habitos', 'Metas em alta',     'Tenha 5 metas aumentadas pela progressão semanal.',                 'raro',  'metas_subiram', 5,  60, 'determinacao', false, 54),
  ('h_perfeito', 'habitos', 'Dias impecáveis',   'Conclua todas as missões diárias do plano em 7 dias.',              'epico', 'dias_perfeitos',7,  90, 'disciplina',   false, 55),
  ('h_retorno',  'habitos', 'Voltar é vencer',   'Cumpra a meta logo depois de um dia em branco.',                    'comum', 'retornos',      1,  30, 'determinacao', false, 56),
  ('h_fenix',    'habitos', 'Fênix',             'Volte depois de um dia em branco 5 vezes.',                         'epico', 'retornos',      5,  80, 'determinacao', false, 57),
  ('h_ajuste',   'habitos', 'Ajuste consciente', 'Reduza uma meta que estava pesada. Ajustar também é evoluir.',      'comum', 'ajustes_baixo', 1,  20, 'foco',         true,  58),
  -- Chefes
  ('c_1', 'chefes', 'Primeira vitória',  'Vença um chefe.',               'raro',     'chefes', 1, 50,  'determinacao', false, 60),
  ('c_4', 'chefes', 'Caça-chefes',       'Vença 4 chefes diferentes.',    'epico',    'chefes', 4, 120, 'determinacao', false, 61),
  ('c_7', 'chefes', 'A forja em paz',    'Vença os 7 chefes.',            'lendario', 'chefes', 7, 300, 'determinacao', false, 62),
  -- Modos
  ('md_desafio',   'modos', 'Espírito desafiante', 'Cumpra a meta em 14 dias no modo Desafio.', 'epico',    'dias_desafio', 14, 100, 'determinacao', false, 70),
  ('md_extremo7',  'modos', 'Sem rede',            'Cumpra a meta em 7 dias no modo Extremo.',  'epico',    'dias_extremo', 7,  120, 'determinacao', false, 71),
  ('md_extremo21', 'modos', 'Inquebrável',         'Cumpra a meta em 21 dias no modo Extremo.', 'lendario', 'dias_extremo', 21, 250, 'determinacao', false, 72)
on conflict (id) do update set
  category = excluded.category, name = excluded.name, description = excluded.description, rarity = excluded.rarity,
  metric = excluded.metric, threshold = excluded.threshold, xp = excluded.xp, attr = excluded.attr,
  hidden = excluded.hidden, sort = excluded.sort;

insert into public.item_catalog (id, kind, slot, name, description, rarity, unlock_type, unlock_level, unlock_ref, sort) values
  -- Cabeça
  ('cab_faixa',         'equipamento', 'cabeca', 'Faixa de ferreiro',  'Segura o suor no primeiro dia de forja.',      'comum',    'inicial',   null, null,         10),
  ('cab_capuz',         'equipamento', 'cabeca', 'Capuz do viajante',  'Para quem já pegou a estrada.',                'comum',    'nivel',     3,    null,         11),
  ('cab_elmo_silencio', 'equipamento', 'cabeca', 'Elmo do Silêncio',   'Abafa o ruído das notificações.',              'raro',     'chefe',     null, 'hidra',      12),
  ('cab_elmo_ferro',    'equipamento', 'cabeca', 'Elmo de ferro',      'Forjado para durar.',                          'raro',     'nivel',     10,   null,         13),
  ('cab_coroa',         'equipamento', 'cabeca', 'Coroa de brasa',     'Sessenta e seis dias seguidos acesos.',        'lendario', 'conquista', null, 's_66',       14),
  -- Corpo
  ('cor_tunica',        'equipamento', 'corpo',  'Túnica de aprendiz', 'Simples e honesta.',                           'comum',    'inicial',   null, null,         20),
  ('cor_gibao',         'equipamento', 'corpo',  'Gibão de couro',     'Couro curtido no trabalho diário.',            'comum',    'nivel',     5,    null,         21),
  ('cor_malha',         'equipamento', 'corpo',  'Cota de malha',      'Mil elos, um para cada esforço.',              'raro',     'nivel',     12,   null,         22),
  ('cor_sentinela',     'equipamento', 'corpo',  'Peitoral da Sentinela', 'Pedra que não cede ao desconforto.',        'epico',    'chefe',     null, 'sentinela',  23),
  ('cor_placas',        'equipamento', 'corpo',  'Armadura de placas', 'Aço sobre aço, camada sobre camada.',          'epico',    'nivel',     20,   null,         24),
  -- Capa
  ('cap_curta',         'equipamento', 'capa',   'Capa curta',         'O primeiro passo para parecer da Forja.',      'comum',    'nivel',     2,    null,         30),
  ('cap_constante',     'equipamento', 'capa',   'Manto do Constante', 'Tecido com fios de todos os dias.',            'epico',    'chefe',     null, 'errante',    31),
  ('cap_fenix',         'equipamento', 'capa',   'Capa da Fênix',      'Para quem sempre volta.',                      'epico',    'conquista', null, 'h_fenix',    32),
  ('cap_mestre',        'equipamento', 'capa',   'Capa da Bigorna',    'Forro de brasa, peso de experiência.',         'lendario', 'nivel',     25,   null,         33),
  -- Arma (ferramenta)
  ('arm_martelo',       'equipamento', 'arma',   'Martelo de aprendiz','Leve, mas já faz faísca.',                     'comum',    'inicial',   null, null,         40),
  ('arm_cajado',        'equipamento', 'arma',   'Cajado do Erudito',  'Ilumina o que a névoa esconde.',               'raro',     'chefe',     null, 'nevoa',      41),
  ('arm_lamina',        'equipamento', 'arma',   'Lâmina do Foco',     'Corta distrações pela raiz.',                  'raro',     'conquista', null, 'a_foco',     42),
  ('arm_martelo_juiz',  'equipamento', 'arma',   'Martelo do Juiz',    'O golpe final da disciplina.',                 'lendario', 'chefe',     null, 'juiz',       43),
  -- Amuleto
  ('amu_ampulheta',     'equipamento', 'amuleto','Ampulheta quebrada', 'O tempo voltou a correr.',                     'raro',     'chefe',     null, 'adiador',    50),
  ('amu_calma',         'equipamento', 'amuleto','Pedra da calma',     'Fria na mão, quente no peito.',                'raro',     'chefe',     null, 'tempestade', 51),
  ('amu_equilibrio',    'equipamento', 'amuleto','Amuleto do equilíbrio','Cinco pontos, um centro.',                   'epico',    'conquista', null, 'a_equilibrio', 52),
  -- Moldura (evolui com o nível)
  ('mol_bronze',        'equipamento', 'moldura','Moldura de bronze',  'Onde toda forja começa.',                      'comum',    'inicial',   null, null,         60),
  ('mol_ferro',         'equipamento', 'moldura','Moldura de ferro',   'Rebites firmes, primeiros resultados.',        'comum',    'nivel',     4,    null,         61),
  ('mol_aco',           'equipamento', 'moldura','Moldura de aço',     'Duas voltas de aço temperado.',                'raro',     'nivel',     8,    null,         62),
  ('mol_runas',         'equipamento', 'moldura','Moldura rúnica',     'Marcas de quem já atravessou fases.',          'epico',    'nivel',     15,   null,         63),
  ('mol_chamas',        'equipamento', 'moldura','Moldura de chamas',  'O fogo agora é seu.',                          'lendario', 'nivel',     25,   null,         64),
  ('mol_66',            'equipamento', 'moldura','Moldura dos 66',     'Para quem completou o programa.',              'lendario', 'conquista', null, 'p_66',       65),
  -- Títulos
  ('tit_aprendiz',      'titulo', null, 'Aprendiz da Forja',   'Título inicial.',                   'comum',    'inicial',   null, null,           100),
  ('tit_faisca',        'titulo', null, 'Faísca Constante',    'Alcance o nível 4.',                'comum',    'nivel',     4,    null,           101),
  ('tit_aco',           'titulo', null, 'Aço Temperado',       'Alcance o nível 8.',                'raro',     'nivel',     8,    null,           102),
  ('tit_coracao',       'titulo', null, 'Coração de Bigorna',  'Alcance o nível 15.',               'epico',    'nivel',     15,   null,           103),
  ('tit_lenda',         'titulo', null, 'Lenda da Bigorna',    'Alcance o nível 25.',               'lendario', 'nivel',     25,   null,           104),
  ('tit_ampulhetas',    'titulo', null, 'Quebra-Ampulhetas',   'Vença o Adiador.',                  'raro',     'chefe',     null, 'adiador',      110),
  ('tit_tempestade',    'titulo', null, 'Olho da Tempestade',  'Vença a Tempestade Interna.',       'raro',     'chefe',     null, 'tempestade',   111),
  ('tit_hidra',         'titulo', null, 'Silêncio da Hidra',   'Vença a Hidra das Notificações.',   'raro',     'chefe',     null, 'hidra',        112),
  ('tit_nevoa',         'titulo', null, 'Luz na Névoa',        'Vença a Névoa do Esquecimento.',    'raro',     'chefe',     null, 'nevoa',        113),
  ('tit_muralha',       'titulo', null, 'Muralha Viva',        'Vença a Sentinela de Pedra.',       'epico',    'chefe',     null, 'sentinela',    114),
  ('tit_constante',     'titulo', null, 'Passo Constante',     'Vença o Errante.',                  'epico',    'chefe',     null, 'errante',      115),
  ('tit_juiz',          'titulo', null, 'Marca do Juiz',       'Vença o Juiz da Bigorna.',          'lendario', 'chefe',     null, 'juiz',         116),
  ('tit_fenix',         'titulo', null, 'Fênix',               'Conquista "Fênix".',                'epico',    'conquista', null, 'h_fenix',      120),
  ('tit_equilibrio',    'titulo', null, 'Centro de Equilíbrio','Conquista "Equilíbrio".',           'epico',    'conquista', null, 'a_equilibrio', 121),
  ('tit_desafiante',    'titulo', null, 'Espírito Desafiante', 'Conquista "Espírito desafiante".',  'epico',    'conquista', null, 'md_desafio',   122),
  ('tit_inquebravel',   'titulo', null, 'Inquebrável',         'Conquista "Inquebrável".',          'lendario', 'conquista', null, 'md_extremo21', 123),
  ('tit_incansavel',    'titulo', null, 'Incansável',          'Conquista "Incansável".',           'lendario', 'conquista', null, 'm_750',        124),
  ('tit_cacachefes',    'titulo', null, 'Caça-Chefes',         'Conquista "Caça-chefes".',          'epico',    'conquista', null, 'c_4',          125),
  ('tit_66',            'titulo', null, 'Chama dos 66',        'Conquista "A marca dos 66".',       'lendario', 'conquista', null, 's_66',         126)
on conflict (id) do update set
  kind = excluded.kind, slot = excluded.slot, name = excluded.name, description = excluded.description,
  rarity = excluded.rarity, unlock_type = excluded.unlock_type, unlock_level = excluded.unlock_level,
  unlock_ref = excluded.unlock_ref, sort = excluded.sort;

-- ════════════════════════════════════════════════════════════════════════════
-- 3. Regras por dia (modo e meta)
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._attr_level(p_xp int)
returns int language sql immutable as $$
  select floor(sqrt(greatest(p_xp, 0) / 30.0))::int + 1
$$;

create or replace function public._int_in(p jsonb, lo int, hi int)
returns boolean language sql immutable as $$
  select case when jsonb_typeof(p) = 'number'
              then (p::text)::numeric = trunc((p::text)::numeric) and (p::text)::numeric between lo and hi
              else false end
$$;

-- Estatística de cada dia num intervalo, julgada pelas regras daquele dia:
--   normal  → meta = mínimo diário
--   desafio → meta = maior entre o mínimo e 60% das missões diárias do dia
--   extremo → todas as missões diárias do dia (e pelo menos o mínimo)
create or replace function public._day_stats(p_uid uuid, p_from date, p_to date)
returns table(day date, done int, daily_total int, daily_done int, dims text[], mode text, min_daily int, goal int, goal_met boolean)
language sql stable security definer set search_path = public as $$
  with prof as (
    select timezone, min_daily_missions, mode from profiles where id = p_uid
  ),
  days as (
    select g::date as day from generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') g
  ),
  comp as (
    select (m.completed_at at time zone prof.timezone)::date as day,
           count(*)::int as done,
           array_agg(distinct m.dimension) as dims
      from missions m cross join prof
     where m.user_id = p_uid and m.status = 'concluida'
     group by 1
  ),
  daily as (
    select m.mission_date as day, count(*)::int as total,
           (count(*) filter (where m.status = 'concluida'))::int as ddone
      from missions m
     where m.user_id = p_uid and m.kind = 'diaria' and m.mission_date between p_from and p_to
     group by 1
  ),
  base as (
    select d.day,
           coalesce(c.done, 0) as done,
           coalesce(dl.total, 0) as total,
           coalesce(dl.ddone, 0) as ddone,
           coalesce(c.dims, '{}'::text[]) as dims,
           coalesce(rh.mode, prof.mode) as mode,
           coalesce(rh.min_daily::int, prof.min_daily_missions::int) as min_daily
      from days d
      cross join prof
      left join comp c on c.day = d.day
      left join daily dl on dl.day = d.day
      left join lateral (
        select h.mode, h.min_daily from rules_history h
         where h.user_id = p_uid and h.started_on <= d.day
         order by h.started_on desc, h.id desc limit 1
      ) rh on true
  )
  select day, done, total, ddone, dims, mode, min_daily,
         case mode when 'normal'  then min_daily
                   when 'desafio' then greatest(min_daily, ceil(total * 0.6)::int)
                   else greatest(min_daily, total) end,
         case mode when 'normal'  then done >= min_daily
                   when 'desafio' then done >= greatest(min_daily, ceil(total * 0.6)::int)
                   else ddone >= total and done >= min_daily end
    from base
   order by day
$$;

-- Registra uma mudança de regra a partir de hoje (uma linha por dia; a última escolha do dia vale).
-- Na primeira mudança, guarda também as regras antigas desde o início do programa.
create or replace function public._record_rules(p_uid uuid, p_today date, p_mode text, p_min int, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare prof profiles;
begin
  select * into prof from profiles where id = p_uid for update;
  if not exists (select 1 from rules_history where user_id = p_uid)
     and prof.program_start is not null and prof.program_start < p_today then
    insert into rules_history (user_id, started_on, mode, min_daily, reason)
      values (p_uid, prof.program_start, prof.mode, prof.min_daily_missions, 'inicial');
  end if;
  delete from rules_history where user_id = p_uid and started_on = p_today;
  insert into rules_history (user_id, started_on, mode, min_daily, reason)
    values (p_uid, p_today, p_mode, p_min, p_reason);
  update profiles set mode = p_mode, min_daily_missions = p_min where id = p_uid;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 4. Funções do MVP atualizadas (mesmas assinaturas)
-- ════════════════════════════════════════════════════════════════════════════

-- Recalcula personagem a partir do histórico e avisa quando sobe de nível
create or replace function public._recalc_stats(p_uid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  t record;
  old_level int;
  new_level int;
begin
  select level into old_level from character_stats where user_id = p_uid;
  select coalesce(sum(amount),0) amount,
         coalesce(sum(disciplina),0) d, coalesce(sum(foco),0) f, coalesce(sum(vitalidade),0) v,
         coalesce(sum(conhecimento),0) c, coalesce(sum(determinacao),0) de
    into t from xp_ledger where user_id = p_uid;
  new_level := level_for_xp(t.amount::int);

  update character_stats set
    total_xp     = t.amount,
    level        = new_level,
    disciplina   = base_disciplina   + t.d,
    foco         = base_foco         + t.f,
    vitalidade   = base_vitalidade   + t.v,
    conhecimento = base_conhecimento + t.c,
    determinacao = base_determinacao + t.de,
    updated_at   = now()
  where user_id = p_uid;

  if new_level > coalesce(old_level, 1) then
    insert into user_events (user_id, kind, ref)
      select p_uid, 'nivel', l::text from generate_series(coalesce(old_level, 1) + 1, new_level) l
    on conflict do nothing;
  end if;
end $$;

create or replace function public._apply_day_bonuses(p_uid uuid, p_day date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  met boolean;
  bonuses jsonb := '[]'::jsonb;
  prev_any boolean;
begin
  select * into prof from profiles where id = p_uid;
  select s.goal_met into met from _day_stats(p_uid, p_day, p_day) s;

  if met then
    insert into xp_ledger (user_id, source, day, amount, disciplina)
      values (p_uid, 'meta_diaria', p_day, 15, 15) on conflict do nothing;
    if found then bonuses := bonuses || '[{"tipo":"meta_diaria","xp":15}]'::jsonb; end if;

    if p_day - 1 >= prof.program_start
       and _completed_on(p_uid, p_day - 1, prof.timezone) = 0 then
      select exists (select 1 from missions where user_id = p_uid and status = 'concluida'
                      and (completed_at at time zone prof.timezone)::date < p_day - 1) into prev_any;
      if prev_any then
        insert into xp_ledger (user_id, source, day, amount, determinacao)
          values (p_uid, 'retorno', p_day, 20, 20) on conflict do nothing;
        if found then bonuses := bonuses || '[{"tipo":"retorno","xp":20}]'::jsonb; end if;
      end if;
    end if;
  else
    delete from xp_ledger where user_id = p_uid and day = p_day and source in ('meta_diaria','retorno');
  end if;
  return bonuses;
end $$;

-- Jornada: sequência, escudos (limite por modo), consistência e calendário
create or replace function public._journey(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  r record;
  st text;
  cap int;
  streak int := 0;
  best int := 0;
  shields int := 0;
  good_days int := 0;
  past_days int := 0;
  today_met boolean := false;
  days jsonb := '[]'::jsonb;
begin
  select * into prof from profiles where id = p_uid;
  cap := case prof.mode when 'normal' then 2 when 'desafio' then 1 else 0 end;
  if prof.program_start is null then
    return jsonb_build_object('current_streak', 0, 'best_streak', 0, 'shields', 0, 'max_shields', cap,
                              'consistency', null, 'milestones', '[]'::jsonb, 'days', days);
  end if;

  for r in select * from _day_stats(p_uid, prof.program_start, p_today) loop
    cap := case r.mode when 'normal' then 2 when 'desafio' then 1 else 0 end;
    shields := least(shields, cap);

    if r.goal_met then
      st := 'completo';
      streak := streak + 1;
      if streak % 7 = 0 and shields < cap then shields := shields + 1; end if;
    elsif r.day = p_today then
      st := case when r.done > 0 then 'parcial' else 'hoje' end;
    elsif r.done > 0 then
      st := 'parcial';
      streak := 0;
    elsif shields > 0 then
      st := 'protegido';
      shields := shields - 1;
    else
      st := 'vazio';
      streak := 0;
    end if;

    best := greatest(best, streak);
    if r.day < p_today then
      past_days := past_days + 1;
      if st = 'completo' then good_days := good_days + 1; end if;
    elsif st = 'completo' then
      today_met := true;
    end if;
    days := days || jsonb_build_object('date', r.day, 'status', st, 'done', r.done, 'total', r.daily_total,
                                       'goal', r.goal, 'mode', r.mode,
                                       'perfect', r.daily_total > 0 and r.daily_done = r.daily_total);
  end loop;

  if today_met then past_days := past_days + 1; good_days := good_days + 1; end if;

  return jsonb_build_object(
    'current_streak', streak,
    'best_streak', best,
    'shields', shields,
    'max_shields', cap,
    'consistency', case when past_days = 0 then null else round(good_days * 100.0 / past_days) end,
    'milestones', (select coalesce(jsonb_agg(m), '[]') from unnest(array[7,14,21,33,45,66,90,132]) m where m <= best),
    'days', days);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 5. Itens, avatar e títulos
-- ════════════════════════════════════════════════════════════════════════════

-- Libera o que a pessoa já alcançou. Devolve quantos itens novos (fora os iniciais).
create or replace function public._grant_items(p_uid uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  lvl int;
  r record;
  c item_catalog;
  n int := 0;
  av jsonb;
  h bigint;
begin
  -- Aparência inicial diferente para cada pessoa (ela personaliza depois)
  select avatar into av from profiles where id = p_uid;
  if av is null or not (av ? 'equip') then
    h := abs(hashtext(p_uid::text)::bigint);
    update profiles set avatar = jsonb_build_object(
      'pele', h % 6, 'cabelo', (h / 7) % 8, 'corCabelo', (h / 61) % 8, 'barba', 0, 'corRoupa', (h / 13) % 6,
      'personalizado', false,
      'equip', jsonb_build_object('corpo', 'cor_tunica', 'moldura', 'mol_bronze'))
    where id = p_uid;
  end if;

  select level into lvl from character_stats where user_id = p_uid;

  for r in
    insert into user_items (user_id, item_id, source)
    select p_uid, ic.id, ic.unlock_type
      from item_catalog ic
     where ic.unlock_type = 'inicial'
        or (ic.unlock_type = 'nivel' and ic.unlock_level <= coalesce(lvl, 1))
        or (ic.unlock_type = 'conquista' and exists (
              select 1 from user_achievements a where a.user_id = p_uid and a.achievement_id = ic.unlock_ref))
        or (ic.unlock_type = 'chefe' and exists (
              select 1 from user_bosses b where b.user_id = p_uid and b.boss_id = ic.unlock_ref and b.status = 'vencido'))
    on conflict do nothing
    returning item_id
  loop
    select * into c from item_catalog where id = r.item_id;
    if c.unlock_type <> 'inicial' then
      n := n + 1;
      insert into user_events (user_id, kind, ref) values (p_uid, 'item', c.id) on conflict do nothing;
    end if;
    -- A moldura evolui sozinha com o nível (a pessoa pode trocar no inventário)
    if c.slot = 'moldura' and c.unlock_type = 'nivel' then
      update profiles set avatar = jsonb_set(avatar, '{equip,moldura}', to_jsonb(c.id)) where id = p_uid;
    end if;
  end loop;
  return n;
end $$;

create or replace function public.update_avatar(p_avatar jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s text;
  v text;
  equip jsonb := '{}'::jsonb;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  if p_avatar is null or jsonb_typeof(p_avatar) <> 'object' then raise exception 'aparencia_invalida'; end if;
  if not (_int_in(p_avatar->'pele', 0, 5) and _int_in(p_avatar->'cabelo', 0, 7) and _int_in(p_avatar->'corCabelo', 0, 7)
          and _int_in(p_avatar->'barba', 0, 2) and _int_in(p_avatar->'corRoupa', 0, 5)) then
    raise exception 'aparencia_invalida';
  end if;
  if p_avatar ? 'equip' and jsonb_typeof(p_avatar->'equip') <> 'object' then raise exception 'aparencia_invalida'; end if;

  foreach s in array array['cabeca','corpo','capa','arma','amuleto','moldura'] loop
    v := p_avatar->'equip'->>s;
    if v is not null then
      if not exists (select 1 from user_items ui join item_catalog ic on ic.id = ui.item_id
                      where ui.user_id = uid and ui.item_id = v and ic.kind = 'equipamento' and ic.slot = s) then
        raise exception 'item_nao_disponivel: %', v;
      end if;
      equip := equip || jsonb_build_object(s, v);
    end if;
  end loop;
  if not equip ? 'corpo' then equip := equip || '{"corpo":"cor_tunica"}'::jsonb; end if;
  if not equip ? 'moldura' then equip := equip || '{"moldura":"mol_bronze"}'::jsonb; end if;

  update profiles set avatar = jsonb_build_object(
    'pele', (p_avatar->>'pele')::int, 'cabelo', (p_avatar->>'cabelo')::int, 'corCabelo', (p_avatar->>'corCabelo')::int,
    'barba', (p_avatar->>'barba')::int, 'corRoupa', (p_avatar->>'corRoupa')::int,
    'personalizado', true, 'equip', equip)
  where id = uid;
  return (select avatar from profiles where id = uid);
end $$;

create or replace function public.set_title(p_title text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  if p_title is not null and not exists (
       select 1 from user_items ui join item_catalog ic on ic.id = ui.item_id
        where ui.user_id = uid and ui.item_id = p_title and ic.kind = 'titulo') then
    raise exception 'titulo_nao_disponivel';
  end if;
  update profiles set active_title = p_title where id = uid;
  return jsonb_build_object('ok', true);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 6. Conquistas
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._achievement_metrics(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  j jsonb := _journey(p_uid, p_today);
  st character_stats;
  res jsonb;
begin
  select * into st from character_stats where user_id = p_uid;
  select jsonb_build_object(
    'missoes',          (select count(*) from missions where user_id = p_uid and status = 'concluida'),
    'melhor_sequencia', coalesce((j->>'best_streak')::int, 0),
    'dias_ativos',      (select count(*) from jsonb_array_elements(j->'days') e where (e->>'done')::int > 0),
    'dias_perfeitos',   (select count(*) from jsonb_array_elements(j->'days') e where (e->>'perfect')::boolean),
    'dias_desafio',     (select count(*) from jsonb_array_elements(j->'days') e where e->>'status' = 'completo' and e->>'mode' = 'desafio'),
    'dias_extremo',     (select count(*) from jsonb_array_elements(j->'days') e where e->>'status' = 'completo' and e->>'mode' = 'extremo'),
    'nivel',            coalesce(st.level, 1),
    'attr_disciplina',  _attr_level(st.disciplina),
    'attr_foco',        _attr_level(st.foco),
    'attr_vitalidade',  _attr_level(st.vitalidade),
    'attr_conhecimento',_attr_level(st.conhecimento),
    'attr_determinacao',_attr_level(st.determinacao),
    'attr_min',         least(_attr_level(st.disciplina), _attr_level(st.foco), _attr_level(st.vitalidade),
                              _attr_level(st.conhecimento), _attr_level(st.determinacao)),
    'areas',            (select count(distinct dimension) from missions where user_id = p_uid and status = 'concluida'),
    'revisoes',         (select count(*) from missions where user_id = p_uid and status = 'concluida' and kind = 'semanal'),
    'especiais',        (select count(*) from missions where user_id = p_uid and status = 'concluida' and kind = 'especial'),
    'surpresas',        (select count(*) from missions where user_id = p_uid and status = 'concluida' and kind = 'surpresa'),
    'metas_subiram',    (select count(*) from progression_events where user_id = p_uid),
    'ajustes_baixo',    (select count(*) from habit_adjustments where user_id = p_uid and new_target < old_target),
    'retornos',         (select count(*) from xp_ledger where user_id = p_uid and source = 'retorno'),
    'chefes',           (select count(distinct boss_id) from user_bosses where user_id = p_uid and status = 'vencido')
  ) into res;
  return res;
end $$;

-- Desbloqueia o que foi alcançado. Conquistas são permanentes. Devolve quantas novas.
create or replace function public._check_achievements(p_uid uuid, p_today date)
returns int language plpgsql security definer set search_path = public as $$
declare
  m jsonb := _achievement_metrics(p_uid, p_today);
  r record;
  c achievement_catalog;
  n int := 0;
begin
  for r in
    insert into user_achievements (user_id, achievement_id)
    select p_uid, ac.id from achievement_catalog ac
     where coalesce((m->>ac.metric)::int, 0) >= ac.threshold
    on conflict do nothing
    returning achievement_id
  loop
    n := n + 1;
    select * into c from achievement_catalog where id = r.achievement_id;
    if c.xp > 0 then
      insert into xp_ledger (user_id, source, ref, day, amount, disciplina, foco, vitalidade, conhecimento, determinacao)
      values (p_uid, 'conquista', c.id, p_today, c.xp,
              case when c.attr = 'disciplina'   then c.xp else 0 end,
              case when c.attr = 'foco'         then c.xp else 0 end,
              case when c.attr = 'vitalidade'   then c.xp else 0 end,
              case when c.attr = 'conhecimento' then c.xp else 0 end,
              case when c.attr = 'determinacao' then c.xp else 0 end)
      on conflict do nothing;
    end if;
    insert into user_events (user_id, kind, ref) values (p_uid, 'conquista', c.id) on conflict do nothing;
  end loop;
  return n;
end $$;

-- Recalcula personagem, libera itens e conquistas (conquistas podem dar XP e subir o nível de novo).
create or replace function public._progress_rewards(p_uid uuid, p_today date)
returns void language plpgsql security definer set search_path = public as $$
declare
  i int := 0;
begin
  perform _recalc_stats(p_uid);
  perform _grant_items(p_uid);
  loop
    exit when _check_achievements(p_uid, p_today) = 0 or i >= 4;
    perform _recalc_stats(p_uid);
    perform _grant_items(p_uid);
    i := i + 1;
  end loop;
end $$;

create or replace function public._achievements(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare m jsonb := _achievement_metrics(p_uid, p_today);
begin
  return jsonb_build_object('items', (
    select coalesce(jsonb_agg(to_jsonb(ac) || jsonb_build_object(
             'unlocked_at', ua.unlocked_at,
             'current', least(coalesce((m->>ac.metric)::int, 0), ac.threshold),
             'rewards', (select coalesce(jsonb_agg(jsonb_build_object('id', ic.id, 'name', ic.name, 'kind', ic.kind, 'slot', ic.slot, 'rarity', ic.rarity) order by ic.sort), '[]'::jsonb)
                           from item_catalog ic where ic.unlock_type = 'conquista' and ic.unlock_ref = ac.id))
           order by ac.sort), '[]'::jsonb)
      from achievement_catalog ac
      left join user_achievements ua on ua.user_id = p_uid and ua.achievement_id = ac.id));
end $$;

create or replace function public.get_achievements()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _achievements(uid, _local_today(uid));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 7. Chefes
-- ════════════════════════════════════════════════════════════════════════════

-- Progresso de uma batalha, recalculado a partir das missões (sempre coerente, inclusive depois de desfazer):
--   golpe = dia que cumpre a regra do chefe
--   cura  = (Desafio) dia passado sem nenhuma missão · (Extremo) dia passado abaixo da meta
create or replace function public._boss_progress(p_uid uuid, p_fight uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  f user_bosses;
  b boss_catalog;
  r record;
  q boolean;
  h boolean;
  eff int := 0;
  hits int := 0;
  heals int := 0;
  vday date;
  tday boolean := false;
  days jsonb := '[]'::jsonb;
begin
  select * into f from user_bosses where id = p_fight and user_id = p_uid;
  select * into b from boss_catalog where id = f.boss_id;

  for r in select * from _day_stats(p_uid, f.started_on, least(p_today, f.deadline)) loop
    q := case b.hit_rule
           when 'dimensao'    then b.dimension = any(r.dims)
           when 'meta_diaria' then r.goal_met
           else r.daily_total > 0 and r.daily_done = r.daily_total end;
    h := r.day < p_today and ((r.mode = 'desafio' and r.done = 0) or (r.mode = 'extremo' and not r.goal_met));
    if q then eff := eff + 1; hits := hits + 1; end if;
    if h and eff > 0 then eff := eff - 1; heals := heals + 1; else h := false; end if;
    if r.day = p_today then tday := q; end if;
    if eff >= f.hp and vday is null then vday := r.day; end if;
    days := days || jsonb_build_object('date', r.day, 'hit', q, 'heal', h);
  end loop;

  return jsonb_build_object('effective', least(eff, f.hp), 'hits', hits, 'heals', heals,
                            'victory_day', vday, 'today_hit', tday, 'days', days);
end $$;

create or replace function public._sync_boss(p_uid uuid, p_today date, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  f user_bosses;
  b boss_catalog;
  p jsonb;
  before int;
  xp int;
  part1 int;
  st text := 'ativo';
begin
  select * into f from user_bosses where user_id = p_uid and status = 'ativo' for update;
  if not found then return null; end if;
  select * into b from boss_catalog where id = f.boss_id;
  before := f.hits;
  p := _boss_progress(p_uid, f.id, p_today);

  if (p->>'victory_day') is not null then
    st := 'vencido';
    update user_bosses set status = 'vencido', hits = f.hp, heals = (p->>'heals')::int, finished_at = p_now where id = f.id;
    xp := case when f.rematch then round(b.xp_reward * 0.5) else b.xp_reward end;
    part1 := round(xp * 0.7);
    insert into xp_ledger (user_id, source, ref, day, amount, disciplina, foco, vitalidade, conhecimento, determinacao)
    values (p_uid, 'chefe', f.id::text, p_today, xp,
      (case when b.attr_primary = 'disciplina'   then part1 else 0 end) + (case when b.attr_secondary = 'disciplina'   then xp - part1 else 0 end),
      (case when b.attr_primary = 'foco'         then part1 else 0 end) + (case when b.attr_secondary = 'foco'         then xp - part1 else 0 end),
      (case when b.attr_primary = 'vitalidade'   then part1 else 0 end) + (case when b.attr_secondary = 'vitalidade'   then xp - part1 else 0 end),
      (case when b.attr_primary = 'conhecimento' then part1 else 0 end) + (case when b.attr_secondary = 'conhecimento' then xp - part1 else 0 end),
      (case when b.attr_primary = 'determinacao' then part1 else 0 end) + (case when b.attr_secondary = 'determinacao' then xp - part1 else 0 end))
    on conflict do nothing;
    insert into user_events (user_id, kind, ref) values (p_uid, 'chefe_vencido', f.id::text) on conflict do nothing;
  elsif p_today > f.deadline then
    st := 'recuou';
    update user_bosses set status = 'recuou', hits = (p->>'effective')::int, heals = (p->>'heals')::int, finished_at = p_now
     where id = f.id;
    insert into user_events (user_id, kind, ref) values (p_uid, 'chefe_recuou', f.id::text) on conflict do nothing;
  else
    update user_bosses set hits = (p->>'effective')::int, heals = (p->>'heals')::int where id = f.id;
  end if;

  return jsonb_build_object('fight_id', f.id, 'boss_id', b.id, 'name', b.name, 'hp', f.hp, 'before', before,
                            'effective', case when st = 'vencido' then f.hp else (p->>'effective')::int end,
                            'today_hit', (p->>'today_hit')::boolean, 'status', st);
end $$;

create or replace function public._boss_lock(p_uid uuid, b boss_catalog, p_day int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare wins int;
begin
  if p_day < b.unlock_day then
    return jsonb_build_object('reason', 'dia', 'day', b.unlock_day);
  end if;
  select count(distinct boss_id) into wins from user_bosses where user_id = p_uid and status = 'vencido';
  if wins < b.requires_victories then
    return jsonb_build_object('reason', 'vitorias', 'needed', b.requires_victories, 'have', wins);
  end if;
  if b.hit_rule = 'dimensao' and not exists (
       select 1 from user_habits where user_id = p_uid and active and dimension = b.dimension and start_day <= p_day) then
    return jsonb_build_object('reason', 'habito', 'dimension', b.dimension);
  end if;
  return null;
end $$;

create or replace function public._start_boss(p_uid uuid, p_boss text, p_today date, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  b boss_catalog;
  lock jsonb;
  fid uuid;
begin
  select * into prof from profiles where id = p_uid;
  if not prof.onboarding_done then raise exception 'conclua_a_avaliacao'; end if;
  select * into b from boss_catalog where id = p_boss;
  if not found then raise exception 'chefe_nao_encontrado'; end if;
  if exists (select 1 from user_bosses where user_id = p_uid and status = 'ativo') then raise exception 'chefe_ja_ativo'; end if;

  lock := _boss_lock(p_uid, b, (p_today - prof.program_start) + 1);
  if lock is not null then raise exception 'chefe_bloqueado_%', lock->>'reason'; end if;

  insert into user_bosses (user_id, boss_id, started_on, deadline, hp, rematch)
  values (p_uid, b.id, p_today, p_today + b.window_days - 1, b.hp,
          exists (select 1 from user_bosses where user_id = p_uid and boss_id = b.id and status = 'vencido'))
  returning id into fid;

  -- Missões já concluídas hoje contam como o primeiro golpe
  perform _sync_boss(p_uid, p_today, p_now);
  perform _progress_rewards(p_uid, p_today);
  return jsonb_build_object('fight_id', fid);
end $$;

create or replace function public.start_boss(p_boss text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _start_boss(uid, p_boss, _local_today(uid), now());
end $$;

create or replace function public.abandon_boss()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  update user_bosses set status = 'desistiu', finished_at = now() where user_id = uid and status = 'ativo';
  return jsonb_build_object('ok', found);
end $$;

create or replace function public._bosses(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  day_n int;
  act user_bosses;
  r boss_catalog;
  lock jsonb;
  fight jsonb;
  prog jsonb;
  st text;
  nvict int;
  last_fight jsonb;
  res jsonb := '[]'::jsonb;
begin
  select * into prof from profiles where id = p_uid;
  day_n := case when prof.program_start is null then 0 else (p_today - prof.program_start) + 1 end;
  select * into act from user_bosses where user_id = p_uid and status = 'ativo';

  for r in select * from boss_catalog order by sort loop
    lock := null; fight := null;
    select count(*) into nvict from user_bosses where user_id = p_uid and boss_id = r.id and status = 'vencido';
    select jsonb_build_object('status', status, 'finished_at', finished_at, 'hits', hits, 'hp', hp) into last_fight
      from user_bosses where user_id = p_uid and boss_id = r.id and status <> 'ativo'
     order by finished_at desc nulls last limit 1;

    if act.id is not null and act.boss_id = r.id then
      prog := _boss_progress(p_uid, act.id, p_today);
      st := 'ativo';
      fight := jsonb_build_object('id', act.id, 'started_on', act.started_on, 'deadline', act.deadline, 'hp', act.hp,
        'effective', (prog->>'effective')::int, 'heals', (prog->>'heals')::int, 'today_hit', prog->'today_hit',
        'days', prog->'days', 'days_left', act.deadline - p_today + 1, 'rematch', act.rematch);
    else
      lock := _boss_lock(p_uid, r, day_n);
      st := case when lock is not null then 'bloqueado' when nvict > 0 then 'vencido' else 'disponivel' end;
    end if;

    res := res || (to_jsonb(r) || jsonb_build_object(
      'state', st, 'lock', lock, 'fight', fight, 'victories', nvict, 'last', last_fight,
      'rewards', (select coalesce(jsonb_agg(jsonb_build_object('id', ic.id, 'name', ic.name, 'kind', ic.kind, 'slot', ic.slot, 'rarity', ic.rarity) order by ic.sort), '[]'::jsonb)
                    from item_catalog ic where ic.unlock_type = 'chefe' and ic.unlock_ref = r.id)));
  end loop;

  return jsonb_build_object('day', day_n, 'active', act.id, 'mode', prof.mode, 'bosses', res);
end $$;

create or replace function public.get_bosses()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); today date;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  today := _local_today(uid);
  perform _sync_boss(uid, today, now());
  return _bosses(uid, today);
end $$;

create or replace function public._active_boss_summary(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  f user_bosses;
  b boss_catalog;
  p jsonb;
begin
  select * into f from user_bosses where user_id = p_uid and status = 'ativo';
  if not found then return null; end if;
  select * into b from boss_catalog where id = f.boss_id;
  p := _boss_progress(p_uid, f.id, p_today);
  return jsonb_build_object('fight_id', f.id, 'boss_id', b.id, 'name', b.name, 'epithet', b.epithet,
    'hit_rule', b.hit_rule, 'dimension', b.dimension, 'hp', f.hp, 'effective', (p->>'effective')::int,
    'today_hit', (p->>'today_hit')::boolean, 'deadline', f.deadline, 'days_left', f.deadline - p_today + 1);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 8. Modos de dificuldade
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._mode_since(p_uid uuid)
returns date language sql stable security definer set search_path = public as $$
  select coalesce(
    (select min(h.started_on) from rules_history h
      where h.user_id = p_uid and h.mode = p.mode
        and h.started_on > coalesce((select max(x.started_on) from rules_history x
                                      where x.user_id = p_uid and x.mode <> p.mode), '-infinity'::date)),
    p.program_start)
  from profiles p where p.id = p_uid
$$;

create or replace function public._extremo_failures(p_uid uuid, p_today date)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int
    from _day_stats(p_uid, greatest(p_today - 7, coalesce(_mode_since(p_uid), p_today)), p_today - 1) s
   where s.mode = 'extremo' and not s.goal_met
$$;

create or replace function public._mode_info(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  day_n int;
  best int;
  waiting boolean;
begin
  select * into prof from profiles where id = p_uid;
  day_n := case when prof.program_start is null then 0 else (p_today - prof.program_start) + 1 end;
  best := coalesce((_journey(p_uid, p_today)->>'best_streak')::int, 0);
  waiting := prof.mode_cooldown_until is not null and p_today < prof.mode_cooldown_until;
  return jsonb_build_object(
    'mode', prof.mode,
    'since', _mode_since(p_uid),
    'day', day_n,
    'best_streak', best,
    'cooldown_until', case when waiting then prof.mode_cooldown_until end,
    'extremo_failures', case when prof.mode = 'extremo' then _extremo_failures(p_uid, p_today) else 0 end,
    'desafio', jsonb_build_object('available', day_n >= 8, 'unlock_day', 8),
    'extremo', jsonb_build_object('available', day_n >= 22 and best >= 7 and not waiting,
                                  'unlock_day', 22, 'streak_needed', 7));
end $$;

create or replace function public.get_mode_info()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _mode_info(uid, _local_today(uid));
end $$;

create or replace function public._set_mode(p_uid uuid, p_mode text, p_accept boolean, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  info jsonb;
begin
  select * into prof from profiles where id = p_uid;
  if not prof.onboarding_done then raise exception 'conclua_a_avaliacao'; end if;
  if p_mode not in ('normal','desafio','extremo') then raise exception 'modo_invalido'; end if;
  if p_mode = prof.mode then return jsonb_build_object('mode', p_mode, 'changed', false); end if;
  if p_mode <> 'normal' and not coalesce(p_accept, false) then raise exception 'aceite_as_regras'; end if;

  info := _mode_info(p_uid, p_today);
  if p_mode = 'desafio' and not (info->'desafio'->>'available')::boolean then raise exception 'modo_bloqueado_dia'; end if;
  if p_mode = 'extremo' then
    if (info->>'day')::int < 22 then raise exception 'modo_bloqueado_dia'; end if;
    if (info->>'best_streak')::int < 7 then raise exception 'modo_bloqueado_sequencia'; end if;
    if info->>'cooldown_until' is not null then raise exception 'modo_em_espera'; end if;
  end if;

  perform _record_rules(p_uid, p_today, p_mode, prof.min_daily_missions, 'escolha');
  -- Sair do Extremo antes da hora não tem custo de XP, mas é preciso esperar 7 dias para voltar
  if prof.mode = 'extremo' then
    update profiles set mode_cooldown_until = p_today + 7 where id = p_uid;
  end if;
  return jsonb_build_object('mode', p_mode, 'changed', true);
end $$;

create or replace function public.set_mode(p_mode text, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _set_mode(uid, p_mode, p_accept, _local_today(uid));
end $$;

-- No Extremo, 3 dias abaixo da meta em 7 dias levam de volta ao modo Desafio
create or replace function public._check_demotion(p_uid uuid, p_today date)
returns boolean language plpgsql security definer set search_path = public as $$
declare prof profiles;
begin
  select * into prof from profiles where id = p_uid;
  if prof.mode <> 'extremo' then return false; end if;
  if _extremo_failures(p_uid, p_today) < 3 then return false; end if;
  perform _record_rules(p_uid, p_today, 'desafio', prof.min_daily_missions, 'rebaixado');
  update profiles set mode_cooldown_until = p_today + 7 where id = p_uid;
  insert into user_events (user_id, kind, ref) values (p_uid, 'modo_rebaixado', p_today::text) on conflict do nothing;
  return true;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 9. Missões: concluir, desfazer, criar, ajustar (mesmas assinaturas do MVP)
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._complete_mission(p_uid uuid, p_mission uuid, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m missions;
  prof profiles;
  today date;
  xp int;
  n_today int;
  n_custom int;
  part1 int;
  lvl_before int;
  stats character_stats;
  bonuses jsonb;
  boss jsonb;
begin
  select * into prof from profiles where id = p_uid;
  today := (p_now at time zone prof.timezone)::date;

  select * into m from missions where id = p_mission and user_id = p_uid for update;
  if not found then raise exception 'missao_nao_encontrada'; end if;
  if m.status = 'concluida' then
    return jsonb_build_object('ja_concluida', true);
  end if;
  if today < m.mission_date or today > m.due_date then
    raise exception 'fora_do_prazo';
  end if;

  select level into lvl_before from character_stats where user_id = p_uid;

  n_today := _completed_on(p_uid, today, prof.timezone);
  select count(*) into n_custom from missions
   where user_id = p_uid and status = 'concluida' and kind = 'personalizada'
     and (completed_at at time zone prof.timezone)::date = today;

  xp := m.xp_reward;
  if m.kind = 'personalizada' and n_custom >= 3 then xp := greatest(1, round(xp * 0.25)); end if;
  if n_today >= 12 then xp := greatest(1, round(xp * 0.5)); end if;
  -- Regras mais exigentes rendem mais
  xp := greatest(1, round(xp * case prof.mode when 'desafio' then 1.2 when 'extremo' then 1.4 else 1.0 end));

  update missions set status = 'concluida', completed_at = p_now where id = m.id;

  part1 := round(xp * 0.7);
  insert into xp_ledger (user_id, mission_id, source, day, amount, disciplina, foco, vitalidade, conhecimento, determinacao)
  values (p_uid, m.id, 'missao', today, xp,
    (case when m.attr_primary = 'disciplina'   then part1 else 0 end) + (case when m.attr_secondary = 'disciplina'   then xp - part1 else 0 end),
    (case when m.attr_primary = 'foco'         then part1 else 0 end) + (case when m.attr_secondary = 'foco'         then xp - part1 else 0 end),
    (case when m.attr_primary = 'vitalidade'   then part1 else 0 end) + (case when m.attr_secondary = 'vitalidade'   then xp - part1 else 0 end),
    (case when m.attr_primary = 'conhecimento' then part1 else 0 end) + (case when m.attr_secondary = 'conhecimento' then xp - part1 else 0 end),
    (case when m.attr_primary = 'determinacao' then part1 else 0 end) + (case when m.attr_secondary = 'determinacao' then xp - part1 else 0 end));

  bonuses := _apply_day_bonuses(p_uid, today);
  perform _recalc_stats(p_uid);
  boss := _sync_boss(p_uid, today, p_now);
  perform _progress_rewards(p_uid, today);
  select * into stats from character_stats where user_id = p_uid;

  return jsonb_build_object(
    'ja_concluida', false,
    'xp', xp,
    'bonus', bonuses,
    'nivel_antes', lvl_before,
    'nivel', stats.level,
    'xp_total', stats.total_xp,
    'chefe', boss);
end $$;

-- Desfazer (só no mesmo dia). Conquistas e vitórias já alcançadas continuam valendo.
create or replace function public._undo_completion(p_uid uuid, p_mission uuid, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m missions;
  prof profiles;
  today date;
begin
  select * into prof from profiles where id = p_uid;
  today := (p_now at time zone prof.timezone)::date;
  select * into m from missions where id = p_mission and user_id = p_uid for update;
  if not found then raise exception 'missao_nao_encontrada'; end if;
  if m.status <> 'concluida' then return jsonb_build_object('desfeita', false); end if;
  if (m.completed_at at time zone prof.timezone)::date <> today then raise exception 'so_no_mesmo_dia'; end if;

  delete from xp_ledger where mission_id = m.id;
  update missions set status = 'pendente', completed_at = null where id = m.id;
  perform _apply_day_bonuses(p_uid, today);
  perform _recalc_stats(p_uid);
  perform _sync_boss(p_uid, today, p_now);
  return jsonb_build_object('desfeita', true);
end $$;

create or replace function public.create_custom_mission(
  p_name text, p_description text, p_dimension text, p_difficulty int, p_minutes int, p_recurring boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  prof profiles;
  a record;
  today date;
  day_n int;
  n int;
  hid uuid;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  select * into prof from profiles where id = uid;
  if not prof.onboarding_done then raise exception 'conclua_a_avaliacao'; end if;
  if p_dimension not in ('fisica','mental','intelectual','produtividade','digital','autocuidado') then raise exception 'dimensao_invalida'; end if;
  if p_difficulty is null or p_difficulty not between 1 and 3 then raise exception 'dificuldade_invalida'; end if;
  if p_minutes is null or p_minutes not between 1 and 120 then raise exception 'duracao_invalida'; end if;
  if char_length(trim(coalesce(p_name, ''))) not between 1 and 60 then raise exception 'nome_invalido'; end if;

  select * into a from _attr_for_dimension(p_dimension);
  today := _local_today(uid);
  day_n := (today - prof.program_start) + 1;

  if p_recurring then
    -- No Extremo o programa é fixo: dá para criar missões avulsas, mas não hábitos novos
    if prof.mode = 'extremo' then raise exception 'modo_extremo_bloqueia_habitos'; end if;
    select count(*) into n from user_habits where user_id = uid and active and is_custom;
    if n >= 12 then raise exception 'limite_habitos'; end if;
    if prof.plan = 'free' and n >= 2 then raise exception 'limite_gratuito_personalizadas'; end if;

    insert into user_habits (user_id, name, description, dimension, attr_primary, attr_secondary, difficulty,
                             unit, base_value, step, max_value, est_minutes, current_target, start_day, is_custom)
    values (uid, trim(p_name), left(coalesce(p_description, ''), 280), p_dimension, a.primary_attr, a.secondary_attr,
            p_difficulty, 'min', p_minutes, 0, p_minutes, p_minutes, p_minutes, greatest(day_n, 1), true)
    returning id into hid;
    perform _ensure_day(uid, today);
    return jsonb_build_object('habit_id', hid);
  else
    select count(*) into n from missions where user_id = uid and kind = 'personalizada' and mission_date = today;
    if n >= 5 then raise exception 'limite_diario_personalizadas'; end if;
    perform _insert_mission(uid, null, 'c:' || gen_random_uuid(), 'personalizada', trim(p_name),
      left(coalesce(p_description, ''), 280), p_dimension, a.primary_attr, a.secondary_attr, p_difficulty,
      p_minutes, 'min', p_minutes, 'qualquer', 'unica', today, today);
    return jsonb_build_object('ok', true);
  end if;
end $$;

create or replace function public.adjust_habit(p_habit uuid, p_target int, p_active boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  h user_habits;
  today date;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  select * into h from user_habits where id = p_habit and user_id = uid for update;
  if not found then raise exception 'habito_nao_encontrado'; end if;
  if (select mode from profiles where id = uid) = 'extremo' then raise exception 'modo_extremo_bloqueia_ajustes'; end if;
  if p_target is null or p_target not between h.base_value and h.max_value then raise exception 'meta_fora_do_intervalo'; end if;

  if p_target <> h.current_target or coalesce(p_active, h.active) <> h.active then
    insert into habit_adjustments (user_id, habit_id, old_target, new_target, paused)
      values (uid, h.id, h.current_target, p_target, coalesce(p_active, h.active) = false);
  end if;
  update user_habits set current_target = p_target, active = coalesce(p_active, active) where id = h.id;

  -- A missão pendente de hoje acompanha o ajuste
  today := _local_today(uid);
  update missions m set
    target_value = p_target,
    estimated_minutes = _est_minutes(h.unit, p_target, h.est_minutes),
    xp_reward = _xp_for(m.difficulty, _est_minutes(h.unit, p_target, h.est_minutes), m.kind)
  where m.habit_id = h.id and m.kind = 'diaria' and m.mission_date = today and m.status = 'pendente';

  if p_active = false then
    delete from missions where habit_id = h.id and mission_date = today and status = 'pendente' and kind = 'diaria';
  end if;

  perform _sync_boss(uid, today, now());
  perform _progress_rewards(uid, today);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.update_profile(p_display_name text, p_timezone text, p_min_daily int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  prof profiles;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  select * into prof from profiles where id = uid;
  if p_timezone is not null and not exists (select 1 from pg_timezone_names where name = p_timezone) then
    raise exception 'fuso_invalido';
  end if;
  if p_min_daily is not null and p_min_daily not between 1 and 10 then raise exception 'meta_invalida'; end if;

  update profiles set
    display_name = coalesce(left(trim(p_display_name), 40), display_name),
    timezone = coalesce(p_timezone, timezone)
  where id = uid;

  if p_min_daily is not null and p_min_daily <> prof.min_daily_missions then
    if prof.mode = 'extremo' then raise exception 'modo_extremo_bloqueia_ajustes'; end if;
    if prof.onboarding_done then
      perform _record_rules(uid, _local_today(uid), prof.mode, p_min_daily, 'escolha');
    else
      update profiles set min_daily_missions = p_min_daily where id = uid;
    end if;
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 10. Abertura do dia e avisos
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._daily_maintenance(p_uid uuid, p_today date, p_now timestamptz)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform _check_demotion(p_uid, p_today);
  perform _sync_boss(p_uid, p_today, p_now);
  perform _progress_rewards(p_uid, p_today);
end $$;

create or replace function public.ensure_today()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  today date;
  r jsonb;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  today := _local_today(uid);
  r := _ensure_day(uid, today);
  if coalesce((r->>'onboarding_done')::boolean, false) then
    perform _daily_maintenance(uid, today, now());
    r := r || jsonb_build_object('mode', (select mode from profiles where id = uid),
                                 'boss', _active_boss_summary(uid, today));
  end if;
  return r;
end $$;

create or replace function public.pending_events()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id, 'kind', e.kind, 'ref', e.ref, 'created_at', e.created_at,
      'data', case e.kind
        when 'nivel' then jsonb_build_object('level', e.ref::int)
        when 'conquista' then (select to_jsonb(ac) || jsonb_build_object(
            'rewards', (select coalesce(jsonb_agg(jsonb_build_object('id', ic.id, 'name', ic.name, 'kind', ic.kind, 'slot', ic.slot, 'rarity', ic.rarity) order by ic.sort), '[]'::jsonb)
                          from item_catalog ic where ic.unlock_type = 'conquista' and ic.unlock_ref = ac.id))
          from achievement_catalog ac where ac.id = e.ref)
        when 'item' then (select to_jsonb(ic) from item_catalog ic where ic.id = e.ref)
        when 'chefe_vencido' then (select jsonb_build_object(
            'boss', to_jsonb(b), 'fight', to_jsonb(f),
            'xp', (select l.amount from xp_ledger l where l.user_id = uid and l.source = 'chefe' and l.ref = f.id::text),
            'rewards', case when f.rematch then '[]'::jsonb else
              (select coalesce(jsonb_agg(jsonb_build_object('id', ic.id, 'name', ic.name, 'kind', ic.kind, 'slot', ic.slot, 'rarity', ic.rarity) order by ic.sort), '[]'::jsonb)
                 from item_catalog ic where ic.unlock_type = 'chefe' and ic.unlock_ref = b.id) end)
          from user_bosses f join boss_catalog b on b.id = f.boss_id where f.id::text = e.ref and f.user_id = uid)
        when 'chefe_recuou' then (select jsonb_build_object('boss', to_jsonb(b), 'fight', to_jsonb(f))
          from user_bosses f join boss_catalog b on b.id = f.boss_id where f.id::text = e.ref and f.user_id = uid)
        else jsonb_build_object('date', e.ref)
      end) order by e.id), '[]'::jsonb)
    from user_events e where e.user_id = uid and not e.seen);
end $$;

create or replace function public.mark_events_seen(p_ids bigint[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); n int;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  update user_events set seen = true where user_id = uid and id = any(p_ids) and not seen;
  get diagnostics n = row_count;
  return jsonb_build_object('marked', n);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 11. Permissões
-- ════════════════════════════════════════════════════════════════════════════

revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.submit_assessment(jsonb),
  public.ensure_today(),
  public.complete_mission(uuid),
  public.undo_completion(uuid),
  public.create_custom_mission(text, text, text, int, int, boolean),
  public.adjust_habit(uuid, int, boolean),
  public.update_profile(text, text, int),
  public.get_journey(),
  public.xp_for_level(int),
  public.level_for_xp(int),
  public.get_bosses(),
  public.start_boss(text),
  public.abandon_boss(),
  public.get_achievements(),
  public.update_avatar(jsonb),
  public.set_title(text),
  public.set_mode(text, boolean),
  public.get_mode_info(),
  public.pending_events(),
  public.mark_events_seen(bigint[])
to authenticated;
