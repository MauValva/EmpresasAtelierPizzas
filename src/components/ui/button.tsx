import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";
import type { ButtonHTMLAttributes } from "react";

const buttonVariants = cva("inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent disabled:pointer-events-none disabled:opacity-50", {
  variants: {
    variant: {
      default: "bg-accent text-background hover:bg-accent/90",
      secondary: "bg-elevated text-foreground hover:bg-elevated/80",
      ghost: "text-muted hover:bg-elevated hover:text-foreground",
      outline: "border border-border bg-transparent text-foreground hover:bg-elevated",
    },
    size: { default: "h-11", sm: "h-10 px-3 text-xs", icon: "h-11 w-11 p-0" },
  },
  defaultVariants: { variant: "default", size: "default" },
});

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> { asChild?: boolean }

export function Button({ className, variant, size, asChild = false, ...props }: ButtonProps) {
  const Comp = asChild ? Slot : "button";
  return <Comp className={cn(buttonVariants({ variant, size, className }))} {...props} />;
}
