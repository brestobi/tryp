import { motion, Variants } from 'framer-motion';
import { ReactNode } from 'react';

interface RevealProps {
  children: ReactNode;
  delay?: number;
  y?: number;
  className?: string;
  as?: 'div' | 'section';
  stagger?: boolean;
  id?: string;
}

const base: Variants = {
  hidden: { opacity: 0, y: 36 },
  show: (i: number = 0) => ({
    opacity: 1,
    y: 0,
    transition: { duration: 0.7, delay: i, ease: [0.16, 1, 0.3, 1] },
  }),
};

/** Fades + slides an element up into place once it scrolls into view. */
export function Reveal({ children, delay = 0, className, as = 'div', id }: RevealProps) {
  const Comp = motion[as];
  return (
    <Comp
      id={id}
      className={className}
      initial="hidden"
      whileInView="show"
      viewport={{ once: true, amount: 0.2 }}
      custom={delay}
      variants={base}
    >
      {children}
    </Comp>
  );
}

const stagger: Variants = {
  hidden: {},
  show: { transition: { staggerChildren: 0.1 } },
};

/** Wrap a group of children (e.g. a grid) to stagger their reveal. Children should use RevealItem. */
export function RevealGroup({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <motion.div className={className} initial="hidden" whileInView="show" viewport={{ once: true, amount: 0.15 }} variants={stagger}>
      {children}
    </motion.div>
  );
}

export function RevealItem({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <motion.div className={className} variants={base}>
      {children}
    </motion.div>
  );
}
