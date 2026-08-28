declare module '@vercel/node' {
  export interface VercelRequest {
    method?: string;
    body?: unknown;
  }
  export interface VercelResponse {
    status(code: number): VercelResponse;
    setHeader(name: string, value: string): VercelResponse;
    json(body: unknown): VercelResponse;
  }
}
