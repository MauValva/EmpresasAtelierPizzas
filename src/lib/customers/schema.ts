import { z } from "zod";

const optionalText = (max: number) => z.string().trim().max(max).optional();

export const customerSchema = z.object({
  name: z.string().trim().min(2, "Informe o nome do cliente.").max(120, "Use no máximo 120 caracteres."),
  phone: optionalText(30),
  apartment: optionalText(80),
  address: optionalText(240),
  notes: optionalText(500),
  marketing_consent: z.boolean().default(false),
});

export const customerUpdateSchema = customerSchema.partial().extend({ is_active: z.boolean().optional() });

export type CustomerFormValues = z.infer<typeof customerSchema>;
export type CustomerFormInput = z.input<typeof customerSchema>;
