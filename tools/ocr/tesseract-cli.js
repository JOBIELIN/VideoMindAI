import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createWorker, OEM } from 'tesseract.js';

const args = process.argv.slice(2);
if (args.includes('--version')) {
  process.stdout.write('DoVideoAI Tesseract.js compatibility wrapper 7.0.0\n');
  process.exit(0);
}
if (args.includes('--list-langs')) {
  process.stdout.write('List of available languages (2):\nchi_sim\neng\n');
  process.exit(0);
}

const inputPath = args[0];
const outputTarget = args[1];
const languageIndex = args.indexOf('-l');
const languages = languageIndex >= 0 && args[languageIndex + 1]
  ? args[languageIndex + 1]
  : 'eng';

if (!inputPath || outputTarget !== 'stdout') {
  process.stderr.write('Usage: tesseract <image> stdout [-l chi_sim+eng]\n');
  process.exit(2);
}

const root = dirname(fileURLToPath(import.meta.url));
let worker;
try {
  worker = await createWorker(languages, OEM.LSTM_ONLY, {
    langPath: resolve(root, 'lang-data'),
    cachePath: resolve(root, '.cache'),
  });
  const result = await worker.recognize(resolve(inputPath));
  process.stdout.write(result.data.text ?? '');
} catch (error) {
  process.stderr.write(`${error?.stack ?? error}\n`);
  process.exitCode = 1;
} finally {
  if (worker) {
    await worker.terminate();
  }
}
