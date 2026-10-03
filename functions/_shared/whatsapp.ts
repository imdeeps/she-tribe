// Sends a one-time code through the WhatsApp Business Cloud API (Meta) using an
// approved AUTHENTICATION template that has a "copy code" button.

export interface WhatsAppConfig {
  token: string;
  phoneNumberId: string;
  templateName: string;
  language: string;
  apiVersion: string;
}

export function whatsappSender(cfg: WhatsAppConfig) {
  return async (phoneE164: string, code: string): Promise<void> => {
    const res = await fetch(
      `https://graph.facebook.com/${cfg.apiVersion}/${cfg.phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${cfg.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: phoneE164.replace("+", ""),
          type: "template",
          template: {
            name: cfg.templateName,
            language: { code: cfg.language },
            components: [
              { type: "body", parameters: [{ type: "text", text: code }] },
              {
                type: "button",
                sub_type: "url",
                index: "0",
                parameters: [{ type: "text", text: code }],
              },
            ],
          },
        }),
      },
    );
    if (!res.ok) {
      console.error("WhatsApp API error", res.status, await res.text());
      throw new Error("whatsapp send failed");
    }
  };
}
