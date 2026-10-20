import type { SVGProps } from 'react'

type P = SVGProps<SVGSVGElement> & { size?: number }
const base = (size = 24, sw = 2): SVGProps<SVGSVGElement> => ({
  width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
  strokeWidth: sw, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true,
})

export const Sliders = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}><path d="M4 8h9M17 8h3M4 16h3M11 16h9" /><circle cx="15" cy="8" r="2" /><circle cx="9" cy="16" r="2" /></svg>
)
export const ChevronL = ({ size, ...p }: P) => <svg {...base(size)} {...p}><path d="M15 6l-6 6 6 6" /></svg>
export const ChevronR = ({ size, ...p }: P) => <svg {...base(size)} {...p}><path d="M9 6l6 6-6 6" /></svg>
export const ChevronD = ({ size, ...p }: P) => <svg {...base(size)} {...p}><path d="M6 9l6 6 6-6" /></svg>
export const Plus = ({ size, ...p }: P) => <svg {...base(size, 2.5)} {...p}><path d="M12 5v14M5 12h14" /></svg>
export const Minus = ({ size, ...p }: P) => <svg {...base(size, 2.5)} {...p}><path d="M6 12h12" /></svg>
export const Check = ({ size, ...p }: P) => <svg {...base(size, 3.5)} {...p}><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
export const Flag = ({ size = 16, ...p }: P) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" strokeWidth={2} strokeLinejoin="round" aria-hidden {...p}>
    <path d="M5 21V4h12l-2.5 4L17 12H5" />
  </svg>
)
export const Info = ({ size, ...p }: P) => <svg {...base(size, 2.5)} {...p}><path d="M12 8h.01M12 11v5" /></svg>
