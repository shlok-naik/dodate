export const spring = { type: 'spring', stiffness: 500, damping: 38 } as const
export const softSpring = { type: 'spring', stiffness: 260, damping: 28 } as const

// Stagger children in on mount.
export const listV = { hidden: {}, show: { transition: { staggerChildren: 0.04, delayChildren: 0.05 } } }
export const itemV = { hidden: { opacity: 0, y: 12 }, show: { opacity: 1, y: 0, transition: softSpring } }
