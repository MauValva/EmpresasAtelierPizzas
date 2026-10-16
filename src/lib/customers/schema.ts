import { z } from "zod";

const optionalText = (max: number) => z.string().trim().max(max).optional();

export const customerSchema = z.object({
  name: z.string().trim().min(2, "Informe o nome do cliente.").max(120, "Use no mÃ¡ximo 120 caracteres."),
  phone: optionalText(30),
  pickup_order: z.boolean().default(false),
  delivery_type: z.enum(["condominio", "fora"]).optional(),
  street: optionalText(120),
  address_number: optionalText(30),
  neighborhood: optionalText(100),
  city: optionalText(100),
  building_block: optionalText(40),
  apartment: optionalText(80),
  address: optionalText(240),
});

export const customerUpdateSchema = customerSchema.partial();

export type CustomerFormValues = z.infer<typeof customerSchema>;
export type CustomerFormInput = z.input<typeof customerSchema>;

