export type Handler = (req: Request) => Response | Promise<Response>;

export type Method = "GET" | "POST" | "PUT" | "PATCH" | "DELETE";

export type Routes = Record<string, Partial<Record<Method, Handler>>>;
