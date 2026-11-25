import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export async function resolve(specifier, context, nextResolve) {
  try {
    return await nextResolve(specifier, context);
  } catch (error) {
    if (!specifier.startsWith('.') || !context.parentURL) throw error;
    const base = fileURLToPath(new URL(specifier, context.parentURL));
    for (const candidate of [`${base}.ts`, `${base}.mts`, `${base}/index.ts`]) {
      if (existsSync(candidate)) {
        return { url: new URL(`file://${candidate.replaceAll('\\', '/')}`).href, shortCircuit: true };
      }
    }
    throw error;
  }
}
