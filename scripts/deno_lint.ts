// @ts-nocheck
// deno run --unstable --allow-env --allow-read scripts/deno_lint.ts packages/app
import { walk } from "https://deno.land/std@0.105.0/fs/mod.ts";
console.info(Deno.args);

for (const [index, arg] of Deno.args.entries()) {
  const status = structuredClone({ files: 0, dirs: 0 });
  console.warn(index, arg);

  // (.*/)?.git/ ,target|node_modules, .*db , images
  const skip = [
    /^(.*\/)?\.git\/.*/,
    /^(.*\/)?\.vscode\/.*/,
    /^(.*\/)?build\/.*/,
    /^(.*\/)?android\/.*/,
    /^(.*\/)?ios\/.*/,
    /^(.*\/)?windows\/.*/,
    /^(.*\/)?macos\/.*/,
    /^(.*\/)?\.dart_tool\/.*/,
    /^(.*\/)?((target)|(node_modules))\/.*/,
    /^.*\.db$/,
    /^.*\.((jpeg)|(jpg)|(png)|(ico)|(gif)|(mp3)|(flac)|(wav)|(mp4)|(mkv)|(DS_Store))$/i,
  ];
  // skip.length = 0
  for await (const entry of walk(arg, { skip })) {
    // console.info(index, entry.path);
    if (entry.isDirectory) {
      status.dirs += 1;
    } else if (entry.isFile) {
      status.files += 1;
      try {
        const fc = Deno.readTextFileSync(entry.path);
        // console.info(index, entry.path, "read", fc.length);

        const lines = fc.split("\n");
        for (const [idx, line] of lines.entries()) {
          const unicode = escape(line).indexOf("%u");
          if (unicode > 0) {
            console.info(
              index,
              entry.path,
              "contains unicode, line:",
              idx,
              JSON.stringify(line)
            );
            break;
          }
        }
      } catch (error) {
        console.info(index, entry.path, "read", error);
        continue;
      }
    }
  }
  console.warn(index, arg, status);
}
