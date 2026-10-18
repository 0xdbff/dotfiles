// Build Zsh global-option metadata from the installed npm, not a handwritten
// flag list. npm >=11.13 stopped returning global options from `npm completion`.
// Commands and arguments still delegate to that documented native protocol.
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

const launcher = fs.realpathSync(process.argv[2]);
const roots = [path.resolve(path.dirname(launcher), '..')];
let metadata;
function load(root) {
  try { return require(path.join(root, 'node_modules/@npmcli/config/lib/definitions')); }
  catch { return null; }
}
metadata = load(roots[0]);
if (!metadata) {
  const result = spawnSync(process.argv[2], ['root', '--global'], {
    encoding: 'utf8', timeout: 10000,
    env: {...process.env, NPM_CONFIG_UPDATE_NOTIFIER: 'false'},
  });
  if (result.status === 0) metadata = load(path.join(result.stdout.trim(), 'npm'));
}
if (!metadata?.definitions?.global) throw new Error('Cannot locate installed npm config definitions');

const quote = text => "'" + text.replace(/'/g, "'\\''") + "'";
const escape = text => text.replace(/\\/g, '\\\\').replace(/[\[\]:]/g, '\\$&');
const options = [];
for (const name of Object.keys(metadata.definitions).sort()) {
  if (!/^[a-z][a-z0-9-]*$/i.test(name)) continue;
  const def = metadata.definitions[name];
  const types = Array.isArray(def.type) ? def.type : [def.type];
  const boolean = types.includes(Boolean);
  const bool = boolean && types.every(type => type === Boolean || type === null);
  const description = escape(String(def.description || name).replace(/\s+/g, ' ').trim());
  const repeated = types.includes(Array) ? '*' : '';
  let argument = '';
  if (!bool) {
    const values = types.filter(type => typeof type === 'string');
    const complete = values.length && !types.includes(String) ? '(' + values.map(escape).join(' ') + ')' : types.includes(path) ? '_files' : types.includes(Number) ? '' : '_default';
    argument = (boolean ? '::value:' : ':value:') + complete;
  }
  options.push(repeated + '--' + name + (bool ? '' : boolean ? '=-' : '=') + '[' + description + ']' + argument);
  if (boolean) options.push('--no-' + name + '[Disable ' + description + ']');
  const shorts = Array.isArray(def.short) ? def.short : [def.short];
  for (const short of shorts) {
    if (typeof short === 'string' && /^[a-z]$/i.test(short)) {
      options.push(repeated + '-' + short + '[' + description + ']' + argument);
    }
  }
}
process.stdout.write(`#compdef npm
# Generated from this machine's installed npm configuration definitions.
_dotfiles_npm_native() {
  local -a candidates
  candidates=( "\${(@f)$(COMP_CWORD=$((CURRENT-1)) COMP_LINE="$BUFFER" COMP_POINT=$CURSOR NPM_CONFIG_UPDATE_NOTIFIER=false command npm completion -- "\${words[@]}" 2>/dev/null)}" )
  (( $#candidates )) && compadd -- "\${candidates[@]}"
}
local -a npm_options=(
${options.map(option => '  ' + quote(option)).join('\n')}
)
_arguments -s -S "\${npm_options[@]}" '*:npm argument:_dotfiles_npm_native'
`);
