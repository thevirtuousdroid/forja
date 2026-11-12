type P = { size?: number };
const base = (size = 24) => ({ width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, 'aria-hidden': true });

export const IconHome = ({ size }: P) => (<svg {...base(size)}><path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z" /></svg>);
export const IconTarget = ({ size }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="9" /><circle cx="12" cy="12" r="5" /><circle cx="12" cy="12" r="1" /></svg>);
export const IconMap = ({ size }: P) => (<svg {...base(size)}><path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2z" /><path d="M9 4v14M15 6v14" /></svg>);
export const IconShield = ({ size }: P) => (<svg {...base(size)}><path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z" /></svg>);
export const IconUser = ({ size }: P) => (<svg {...base(size)}><circle cx="12" cy="8" r="4" /><path d="M4 21c1-4 4-6 8-6s7 2 8 6" /></svg>);
export const IconCheck = ({ size = 22 }: P) => (<svg {...base(size)} strokeWidth={3}><path d="m5 12 5 5 9-10" /></svg>);
export const IconFlame = ({ size }: P) => (<svg {...base(size)}><path d="M12 3c2 4 6 6 6 11a6 6 0 0 1-12 0c0-3 1.5-4.5 3-6 .3 2 1.3 3 2.6 3.4C11 8 11.3 5.5 12 3z" /></svg>);
export const IconPlus = ({ size }: P) => (<svg {...base(size)}><path d="M12 5v14M5 12h14" /></svg>);
export const IconChevronLeft = ({ size = 20 }: P) => (<svg {...base(size)}><path d="m15 18-6-6 6-6" /></svg>);
export const IconClock = ({ size = 16 }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg>);
export const IconSpark = ({ size = 16 }: P) => (<svg {...base(size)}><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6" /></svg>);
