import type { Dimension } from '../lib/types';

export interface Option { label: string; value: string | number }
export interface Question {
  key: string;
  title: string;
  hint?: string;
  options: Option[];
  multi?: boolean;
  optional?: boolean;
  /** Resposta em texto livre (sem opções). */
  text?: { placeholder: string; maxLength: number };
}
export interface Step { title: string; intro: string; questions: Question[] }

/** Nas perguntas pontuadas, o valor vai de 0 (situação mais difícil) a 3 (melhor situação). */
export const STEPS: Step[] = [
  {
    title: 'Sobre você',
    intro: 'Para adaptar o ritmo das missões. A idade é opcional.',
    questions: [
      { key: 'display_name', title: 'Como quer ser chamado?', options: [], text: { placeholder: 'Seu nome ou apelido', maxLength: 40 } },
      {
        key: 'age_range', title: 'Qual é a sua faixa de idade?', optional: true,
        options: [
          { label: 'Menos de 18', value: '<18' }, { label: '18 a 24', value: '18-24' }, { label: '25 a 34', value: '25-34' },
          { label: '35 a 49', value: '35-49' }, { label: '50 ou mais', value: '50+' }, { label: 'Prefiro não dizer', value: 'nd' },
        ],
      },
    ],
  },
  {
    title: 'Sua rotina',
    intro: 'O plano precisa caber no seu dia real, não num dia ideal.',
    questions: [
      {
        key: 'wake_time', title: 'Normalmente você acorda…',
        options: [
          { label: 'Antes das 6h', value: 0 }, { label: 'Entre 6h e 8h', value: 1 },
          { label: 'Entre 8h e 10h', value: 2 }, { label: 'Depois das 10h', value: 3 },
        ],
      },
      {
        key: 'free_period', title: 'Em que parte do dia você tem mais tempo livre?',
        options: [
          { label: 'Manhã', value: 'manha' }, { label: 'Tarde', value: 'tarde' },
          { label: 'Noite', value: 'noite' }, { label: 'Varia muito', value: 'variavel' },
        ],
      },
      {
        key: 'daily_minutes', title: 'Quanto tempo por dia você consegue dedicar à sua evolução, de verdade?',
        hint: 'Vamos começar com cerca de 60% disso, para sobrar margem.',
        options: [
          { label: '15 minutos', value: 15 }, { label: '30 minutos', value: 30 }, { label: '45 minutos', value: 45 },
          { label: '1 hora', value: 60 }, { label: '1h30 ou mais', value: 90 },
        ],
      },
    ],
  },
  {
    title: 'Corpo e sono',
    intro: 'Sem julgamento: queremos só o ponto de partida.',
    questions: [
      {
        key: 'sleep_hours', title: 'Quantas horas você costuma dormir?',
        options: [
          { label: 'Menos de 5h', value: 0 }, { label: '5 a 6h', value: 1 }, { label: '6 a 7h', value: 2 }, { label: '7h ou mais', value: 3 },
        ],
      },
      {
        key: 'sleep_quality', title: 'Como você acorda na maioria dos dias?',
        options: [
          { label: 'Sem energia', value: 0 }, { label: 'Com pouca energia', value: 1 }, { label: 'Razoável', value: 2 }, { label: 'Com energia', value: 3 },
        ],
      },
      {
        key: 'exercise', title: 'Em quantos dias da semana você se exercita?',
        options: [
          { label: 'Nenhum', value: 0 }, { label: '1 a 2', value: 1 }, { label: '3 a 4', value: 2 }, { label: '5 ou mais', value: 3 },
        ],
      },
      {
        key: 'diet', title: 'Como você descreveria sua alimentação?',
        options: [
          { label: 'Bem desregulada', value: 0 }, { label: 'Irregular', value: 1 }, { label: 'Razoável', value: 2 }, { label: 'Equilibrada', value: 3 },
        ],
      },
    ],
  },
  {
    title: 'Mente',
    intro: 'Como você tem se sentido nas últimas semanas.',
    questions: [
      {
        key: 'stress', title: 'Com que frequência a rotina parece pesada demais?',
        options: [
          { label: 'Quase sempre', value: 0 }, { label: 'Com frequência', value: 1 }, { label: 'Às vezes', value: 2 }, { label: 'Raramente', value: 3 },
        ],
      },
      {
        key: 'rest', title: 'Você tem momentos de descanso de verdade no dia?',
        options: [
          { label: 'Quase nunca', value: 0 }, { label: 'Poucos', value: 1 }, { label: 'Alguns', value: 2 }, { label: 'Sim, todo dia', value: 3 },
        ],
      },
      {
        key: 'reflection', title: 'Você costuma parar para refletir sobre o seu dia?',
        options: [
          { label: 'Nunca', value: 0 }, { label: 'Raramente', value: 1 }, { label: 'Às vezes', value: 2 }, { label: 'Com frequência', value: 3 },
        ],
      },
    ],
  },
  {
    title: 'Aprendizado e produtividade',
    intro: 'Leitura, estudos e como você lida com as tarefas.',
    questions: [
      {
        key: 'reading', title: 'Com que frequência você lê (livros ou textos longos)?',
        options: [
          { label: 'Quase nunca', value: 0 }, { label: 'Às vezes', value: 1 }, { label: 'Toda semana', value: 2 }, { label: 'Quase todo dia', value: 3 },
        ],
      },
      {
        key: 'learning', title: 'Você está aprendendo algo novo atualmente (curso, idioma, habilidade)?',
        options: [
          { label: 'Não', value: 0 }, { label: 'Quero, mas não comecei', value: 1 }, { label: 'Sim, sem regularidade', value: 2 }, { label: 'Sim, com regularidade', value: 3 },
        ],
      },
      {
        key: 'planning', title: 'Você planeja o seu dia?',
        options: [
          { label: 'Nunca', value: 0 }, { label: 'Raramente', value: 1 }, { label: 'Às vezes', value: 2 }, { label: 'Quase sempre', value: 3 },
        ],
      },
      {
        key: 'procrastination', title: 'Com que frequência você adia tarefas importantes?',
        options: [
          { label: 'Quase sempre', value: 0 }, { label: 'Com frequência', value: 1 }, { label: 'Às vezes', value: 2 }, { label: 'Raramente', value: 3 },
        ],
      },
    ],
  },
  {
    title: 'Telas e foco',
    intro: 'Pensando no uso de lazer, fora do trabalho ou estudo.',
    questions: [
      {
        key: 'screen_time', title: 'Quanto tempo por dia você passa no celular por lazer?',
        options: [
          { label: 'Mais de 6h', value: 0 }, { label: '4 a 6h', value: 1 }, { label: '2 a 4h', value: 2 }, { label: 'Menos de 2h', value: 3 },
        ],
      },
      {
        key: 'phone_morning', title: 'Ao acordar, quando você pega o celular?',
        options: [
          { label: 'Antes de levantar', value: 0 }, { label: 'Nos primeiros minutos', value: 1 },
          { label: 'Depois de me arrumar', value: 2 }, { label: 'Bem depois', value: 3 },
        ],
      },
      {
        key: 'focus', title: 'Quanto tempo você consegue focar numa tarefa sem se distrair?',
        options: [
          { label: 'Menos de 5 min', value: 0 }, { label: '5 a 15 min', value: 1 }, { label: '15 a 30 min', value: 2 }, { label: 'Mais de 30 min', value: 3 },
        ],
      },
    ],
  },
  {
    title: 'Autocuidado',
    intro: 'Os pequenos cuidados que sustentam o resto.',
    questions: [
      {
        key: 'water', title: 'Quantos copos de água você bebe por dia?',
        options: [
          { label: 'Menos de 3', value: 0 }, { label: '3 a 5', value: 1 }, { label: '6 a 8', value: 2 }, { label: 'Mais de 8', value: 3 },
        ],
      },
      {
        key: 'morning_routine', title: 'Você tem uma rotina ao acordar?',
        options: [
          { label: 'Não', value: 0 }, { label: 'Às vezes', value: 1 }, { label: 'Quase sempre', value: 2 }, { label: 'Sim, sempre', value: 3 },
        ],
      },
      {
        key: 'environment', title: 'Como está o seu ambiente (quarto, mesa)?',
        options: [
          { label: 'Bagunçado', value: 0 }, { label: 'Mais bagunçado que arrumado', value: 1 },
          { label: 'Razoável', value: 2 }, { label: 'Organizado', value: 3 },
        ],
      },
      {
        key: 'discipline', title: 'De 0 a 3, como você avalia a sua disciplina hoje?',
        options: [
          { label: '0 · Começo do zero', value: 0 }, { label: '1 · Pouco', value: 1 }, { label: '2 · Razoável', value: 2 }, { label: '3 · Bastante', value: 3 },
        ],
      },
    ],
  },
  {
    title: 'Seus objetivos',
    intro: 'O seu objetivo principal sempre entra no plano, mesmo que não seja o ponto mais fraco.',
    questions: [
      {
        key: 'main_goal', title: 'Qual área você mais quer desenvolver agora?',
        options: (
          [
            ['fisica', 'Saúde física'], ['mental', 'Saúde mental'], ['intelectual', 'Aprendizado'],
            ['produtividade', 'Disciplina e produtividade'], ['digital', 'Menos tela, mais foco'], ['autocuidado', 'Autocuidado e rotina'],
          ] as [Dimension, string][]
        ).map(([value, label]) => ({ label, value })),
      },
      {
        key: 'difficulties', title: 'Quais são as suas principais dificuldades?', hint: 'Marque quantas quiser.', multi: true, optional: true,
        options: [
          { label: 'Procrastinação', value: 'procrastinacao' }, { label: 'Falta de tempo', value: 'tempo' },
          { label: 'Celular e redes', value: 'celular' }, { label: 'Cansaço', value: 'cansaco' },
          { label: 'Falta de motivação', value: 'motivacao' }, { label: 'Começo e paro', value: 'inconstancia' },
        ],
      },
    ],
  },
];

export const TOTAL_QUESTIONS = STEPS.reduce((n, s) => n + s.questions.length, 0);

export function isStepComplete(step: Step, answers: Record<string, unknown>): boolean {
  return step.questions.every((q) => {
    const v = answers[q.key];
    if (q.optional) return true;
    if (q.text) return typeof v === 'string' && v.trim().length > 0;
    return v !== undefined && v !== null;
  });
}
