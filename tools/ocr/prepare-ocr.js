import { copyFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const languageDirectory = join(root, 'lang-data');
await mkdir(languageDirectory, { recursive: true });

for (const language of ['chi_sim', 'eng']) {
  await copyFile(
    join(root, 'node_modules', '@tesseract.js-data', language, '4.0.0', `${language}.traineddata.gz`),
    join(languageDirectory, `${language}.traineddata.gz`),
  );
}
