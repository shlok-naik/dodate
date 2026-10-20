import { motion } from 'framer-motion'

export type Mood = 'sleep' | 'chill' | 'party' | 'write' | 'sweat'

const LABELS: Record<Mood, string> = {
  sleep: 'A dodo asleep in a nightcap',
  chill: 'A dodo in sunglasses under the sun',
  party: 'A dodo in a party hat, cheering',
  write: 'A dodo holding a pencil',
  sweat: 'A worried dodo, sweating',
}

// Pivot point in the 160×160 viewBox.
const o = (x: number, y: number) => ({ transformBox: 'view-box' as const, transformOrigin: `${x}px ${y}px` })

const loop = { repeat: Infinity, ease: 'easeInOut' } as const

// The Dodate mascot. Each mood has its own idle animation.
export function Dodo({ mood = 'party', size = 160 }: { mood?: Mood; size?: number }) {
  const eyeOpen = mood !== 'sleep' && mood !== 'chill'
  const bob = mood === 'party' ? { y: [0, -8, 0], rotate: [0, -3, 0, 3, 0] } : mood === 'sleep' ? { scaleY: [1, 1.03, 1] } : mood === 'sweat' ? { x: [0, -1.5, 1.5, 0] } : { y: [0, -2, 0] }
  const bobT = mood === 'party' ? { duration: 0.9, ...loop } : mood === 'sleep' ? { duration: 3, ...loop } : mood === 'sweat' ? { duration: 0.4, ...loop, repeatDelay: 1.2 } : { duration: 2.4, ...loop }

  return (
    <div role="img" aria-label={LABELS[mood]} style={{ position: 'relative', width: size, height: size, flex: 'none' }}>
      <svg aria-hidden width={size} height={size} viewBox="0 0 160 160" style={{ position: 'absolute', inset: 0, overflow: 'visible' }}>
        <motion.ellipse cx="80" cy="148" rx="44" ry="5" fill="#121614" opacity={0.07}
          animate={mood === 'party' ? { scaleX: [1, 0.8, 1] } : {}} transition={{ duration: 0.9, ...loop }} style={o(80, 148)} />
        <path d="M68 128v14M92 128v14M62 142h10M86 142h10" stroke="#E0A93F" strokeWidth="5" strokeLinecap="round" fill="none" />
        <motion.g animate={bob} transition={bobT} style={o(80, 140)}>
          <motion.path d="M36 92c-10-6-14-16-10-22 6 2 9 8 10 12 0-8 4-14 10-15 2 7-1 14-4 18" fill="#F3EEE4"
            animate={{ rotate: [0, -6, 0] }} transition={{ duration: 1.6, ...loop }} style={o(44, 90)} />
          <ellipse cx="80" cy="100" rx="48" ry="38" fill="#8FA8B8" />
          <ellipse cx="90" cy="110" rx="27" ry="22" fill="#D3DEE5" />
          {mood === 'party' ? (
            <motion.path d="M40 92c-8-10-10-20-6-28" stroke="#7892A4" strokeWidth="10" strokeLinecap="round" fill="none"
              animate={{ rotate: [0, 18, 0] }} transition={{ duration: 0.45, ...loop }} style={o(40, 92)} />
          ) : (
            <ellipse cx="62" cy="102" rx="19" ry="13" fill="#7892A4" transform="rotate(-18 62 102)" />
          )}
          <circle cx="106" cy="58" r="24" fill="#8FA8B8" />
          <path d="M100 76c4 8 6 14 6 22" stroke="#8FA8B8" strokeWidth="18" strokeLinecap="round" fill="none" />
          <path d="M121 50c14-2 27 4 31 14 2 6-1 12-7 12-2-5-6-7-11-7l-14 2c-4-6-4-15 1-21z" fill="#F2B33D" />
          <path d="M145 76c-2-5-6-7-11-7" stroke="#C98516" strokeWidth="3" strokeLinecap="round" fill="none" />
          <circle cx="101" cy="67" r="4.5" fill="#F09AB4" opacity="0.7" />

          {eyeOpen && (
            <motion.g animate={{ scaleY: [1, 1, 0.1, 1] }} transition={{ duration: 4, times: [0, 0.92, 0.96, 1], repeat: Infinity }} style={o(111, 52)}>
              <circle cx="111" cy="52" r="4.5" fill="#121614" />
              <circle cx="112.6" cy="50.4" r="1.6" fill="#FFFFFF" />
            </motion.g>
          )}

          {mood === 'sleep' && (
            <>
              <path d="M106 53c2 3 7 3 9 0" stroke="#121614" strokeWidth="2.5" strokeLinecap="round" fill="none" />
              <path d="M88 40c-4-14 4-26 18-26 10 0 16 6 18 12-10-3-22 0-36 14z" fill="#3D6FD1" />
              <circle cx="124" cy="25" r="5" fill="#F3EEE4" />
            </>
          )}
          {mood === 'chill' && (
            <>
              <rect x="99" y="46" width="18" height="11" rx="5" fill="#121614" />
              <path d="M99 50h-8" stroke="#121614" strokeWidth="2.5" strokeLinecap="round" />
              <path d="M103 49l5-2" stroke="#FFFFFF" strokeWidth="1.6" strokeLinecap="round" opacity="0.7" />
            </>
          )}
          {mood === 'party' && (
            <motion.g animate={{ rotate: [0, -8, 0, 8, 0] }} transition={{ duration: 0.9, ...loop }} style={o(106, 37)}>
              <path d="M94 37l10-30 14 26z" fill="#7B5CD6" />
              <path d="M97 28l15-3M100 19l9-2" stroke="#F2C94C" strokeWidth="3" strokeLinecap="round" />
              <circle cx="104" cy="6" r="4" fill="#C84D74" />
            </motion.g>
          )}
          {mood === 'write' && (
            <motion.g animate={{ rotate: [-35, -28, -38, -35], x: [0, 2, -1, 0] }} transition={{ duration: 0.8, ...loop }} style={o(46, 92)}>
              <rect x="40" y="52" width="12" height="56" rx="2" fill="#F2C94C" />
              <rect x="40" y="52" width="12" height="10" rx="2" fill="#F09AB4" />
              <rect x="40" y="60" width="12" height="4" fill="#C2C7C3" />
              <path d="M40 108l6 12 6-12z" fill="#F3DFB6" />
              <path d="M44.5 116l1.5 4 1.5-4z" fill="#121614" />
            </motion.g>
          )}
          {mood === 'write' && <ellipse cx="56" cy="98" rx="10" ry="8" fill="#7892A4" />}
          {mood === 'sweat' && <path d="M104 42l12-4" stroke="#121614" strokeWidth="2.5" strokeLinecap="round" />}
        </motion.g>

        {mood === 'sleep' && [0, 1, 2].map((i) => (
          <motion.text key={i} x={128} y={22} fontFamily="Arial, sans-serif" fontWeight={700} fontSize={14 - i * 2} fill="#7B5CD6"
            initial={{ opacity: 0, x: 0, y: 0 }} animate={{ opacity: [0, 1, 0], x: [0, 10, 18], y: [0, -14, -26] }}
            transition={{ duration: 2.4, delay: i * 0.8, repeat: Infinity, ease: 'easeOut' }}>z</motion.text>
        ))}
        {mood === 'chill' && (
          <motion.g animate={{ rotate: 360 }} transition={{ duration: 12, repeat: Infinity, ease: 'linear' }} style={o(28, 30)}>
            <circle cx="28" cy="30" r="12" fill="#F2C94C" />
            <path d="M28 8v6M28 46v6M6 30h6M44 30h6M12 14l4 4M40 42l4 4M12 46l4-4M40 18l4-4" stroke="#F2C94C" strokeWidth="3" strokeLinecap="round" />
          </motion.g>
        )}
        {mood === 'sweat' && [[88, 30, 7, 0], [78, 48, 4, 0.5]].map(([x, y, r, delay]) => (
          <motion.path key={x} d={`M${x} ${y}c0 0-${r} ${r * 1.3}-${r} ${r * 1.9}a${r} ${r} 0 0 0 ${r * 2} 0c0-${r * 0.6}-${r}-${r * 1.9}-${r}-${r * 1.9}z`} fill="#8DB4F5"
            animate={{ y: [0, 10], opacity: [1, 0] }} transition={{ duration: 1.2, delay, repeat: Infinity, ease: 'easeIn' }} />
        ))}
        {mood === 'party' && [
          ['#3D6FD1', 18, 40, 30], ['#C84D74', 40, 18, -20], ['#2E8C63', 140, 98, 40], ['#E0A93F', 132, 22, -40],
        ].map(([fill, x, y, r], i) => (
          <motion.rect key={i} x={x as number} y={y as number} width="8" height="4" rx="2" fill={fill as string}
            animate={{ rotate: [r as number, (r as number) + 180], y: [0, -6, 0] }}
            transition={{ duration: 1.4 + i * 0.2, repeat: Infinity, ease: 'easeInOut' }} style={o((x as number) + 4, (y as number) + 2)} />
        ))}
      </svg>
    </div>
  )
}
