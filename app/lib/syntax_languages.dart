import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

/// Every language the app highlights: highlight.js's, and the ones it hasn't.
Map<String, Mode> get syntaxLanguages => {
  ...builtinAllLanguages,
  'jsonnet': _jsonnet(),
  'hcl': _hcl(),
  'zig': _zig(),
};

/// Tags and file names that read well enough in another language's grammar,
/// by that language. A name is a file's extension or its whole name.
const syntaxAliases = {
  'bash': ['zsh', 'fish', 'ksh', 'env'],
  'clojure': ['cljs', 'cljc', 'edn'],
  'django': ['j2', 'jinja2'],
  'dockerfile': ['containerfile'],
  'erlang': ['hrl'],
  'fsharp': ['fsx'],
  'glsl': ['vert', 'frag', 'wgsl'],
  'haskell': ['lhs'],
  'ini': ['conf', 'cfg', 'editorconfig'],
  'javascript': ['cts', 'mts'],
  'json': ['jsonc', 'json5', 'jsonl', 'ndjson', 'ipynb'],
  'julia': ['jl'],
  'makefile': ['justfile', 'just'],
  'markdown': ['mdx'],
  'ocaml': ['mli'],
  'python': [
    'pyi',
    'pyx',
    'bzl',
    'bazel',
    'starlark',
    'build',
    'workspace',
    'tiltfile',
  ],
  'ruby': ['rake', 'gemfile', 'rakefile', 'brewfile', 'vagrantfile'],
  'scala': ['sc'],
  'vhdl': ['vhd'],
  'xml': ['htm', 'svelte', 'astro'],
};

Mode _strings(List<Mode> inside) => Mode(
  className: 'string',
  contains: [BACKSLASH_ESCAPE, ...inside],
  variants: [
    Mode(begin: '"', end: '"'),
    Mode(begin: "'", end: "'"),
  ],
);

Mode _jsonnet() => Mode(
  name: 'Jsonnet',
  aliases: ['libsonnet'],
  keywords: {
    'keyword': [
      'assert', 'else', 'error', 'for', 'function', 'if', 'import', //
      'importbin', 'importstr', 'in', 'local', 'tailstrict', 'then',
    ],
    'literal': ['true', 'false', 'null'],
    'built_in': ['self', 'super', 'std'],
  },
  contains: [
    C_LINE_COMMENT_MODE,
    C_BLOCK_COMMENT_MODE,
    HASH_COMMENT_MODE,
    // A text block, then verbatim strings, which have no escapes.
    Mode(className: 'string', begin: r'\|\|\|', end: r'\|\|\|'),
    Mode(className: 'string', begin: '@"', end: '"'),
    Mode(className: 'string', begin: "@'", end: "'"),
    _strings([]),
    C_NUMBER_MODE,
    Mode(className: 'attr', begin: r'[A-Za-z_]\w*(?=\s*\+?:{1,3}[^:])'),
    Mode(className: 'title', begin: r'(?<=local\s+)[A-Za-z_]\w*(?=\s*\()'),
  ],
);

Mode _hcl() {
  final subst = Mode(className: 'subst', begin: r'[$%]\{', end: r'\}');
  return Mode(
    name: 'HCL',
    aliases: ['tf', 'tfvars', 'terraform'],
    keywords: {
      'keyword': ['for', 'in', 'if', 'else', 'endif', 'endfor'],
      'literal': ['true', 'false', 'null'],
      'built_in': [
        'string',
        'number',
        'bool',
        'list',
        'map',
        'set',
        'object',
        'tuple',
        'any',
      ],
    },
    contains: [
      C_LINE_COMMENT_MODE,
      C_BLOCK_COMMENT_MODE,
      HASH_COMMENT_MODE,
      Mode(
        className: 'string',
        begin: '"',
        end: '"',
        contains: [BACKSLASH_ESCAPE, subst],
      ),
      Mode(className: 'string', begin: '<<-?[A-Z_]+', end: r'^\s*[A-Z_]+\s*$'),
      C_NUMBER_MODE,
      // A block's type: `resource "aws_s3_bucket" "logs" {`.
      Mode(className: 'keyword', begin: r'^\s*[\w-]+(?=(\s+"[^"\n]*")*\s*\{)'),
      Mode(className: 'attr', begin: r'[\w-]+(?=\s*=[^=>])'),
    ],
  );
}

Mode _zig() => Mode(
  name: 'Zig',
  keywords: {
    'keyword': [
      'addrspace', 'align', 'allowzero', 'and', 'anyframe', 'asm', 'async', //
      'await', 'break', 'callconv', 'catch', 'comptime', 'const', 'continue',
      'defer', 'else', 'enum', 'errdefer', 'error', 'export', 'extern', 'fn',
      'for', 'if', 'inline', 'linksection', 'noalias', 'noinline', 'nosuspend',
      'opaque', 'or', 'orelse', 'packed', 'pub', 'resume', 'return', 'struct',
      'suspend', 'switch', 'test', 'threadlocal', 'try', 'union', 'unreachable',
      'usingnamespace', 'var', 'volatile', 'while',
    ],
    'literal': ['true', 'false', 'null', 'undefined'],
    'type': [
      'anyerror', 'anyopaque', 'anytype', 'bool', 'comptime_float', //
      'comptime_int', 'isize', 'noreturn', 'type', 'usize', 'void',
    ],
  },
  contains: [
    C_LINE_COMMENT_MODE,
    Mode(className: 'string', begin: r'\\\\', end: r'$'),
    _strings([]),
    C_NUMBER_MODE,
    Mode(className: 'type', begin: r'\b[iuf]\d+\b'),
    Mode(className: 'built_in', begin: r'@[A-Za-z_]\w*'),
    Mode(className: 'title', begin: r'(?<=\bfn\s+)[A-Za-z_]\w*'),
  ],
);
