module.exports = {
  env: {
    browser: true,
    es6: true,
  },
  extends: [
    "plugin:@typescript-eslint/recommended",
    "prettier",
    "prettier/@typescript-eslint",
    "plugin:mocha/recommended",
  ],
  ignorePatterns: ["node_modules/"],
  globals: {
    Atomics: "readonly",
    SharedArrayBuffer: "readonly",
  },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    createDefaultProgram: true,
    ecmaFeatures: {
      jsx: true,
    },
    ecmaVersion: 2018,
    project: "./tsconfig.json",
    sourceType: "module",
  },
  plugins: ["import", "prettier", "sort-keys-shorthand"],
  rules: {
    /* TypeScript formatting */
    "@typescript-eslint/explicit-function-return-type": "off", // TypeScript infers this stuff well
    "@typescript-eslint/member-ordering": [
      "error",
      {
        default: [
          "public-static-field",
          "protected-static-field",
          "private-static-field",
          "static-field",
          "public-static-method",
          "protected-static-method",
          "private-static-method",
          "static-method",
          "public-instance-field",
          "protected-instance-field",
          "private-instance-field",
          "public-field",
          "protected-field",
          "private-field",
          "instance-field",
          "field",
          "constructor",
          "public-instance-method",
          "protected-instance-method",
          "private-instance-method",
          "public-method",
          "protected-method",
          "private-method",
          "instance-method",
          "method",
        ],
      },
    ],
    "@typescript-eslint/no-explicit-any": "off", // TODO: Investigate re-enabling; this would be tricky
    "@typescript-eslint/no-namespace": "off", // TODO: Not clear on why this is a thing but it messes with our extended enums
    "@typescript-eslint/no-unnecessary-type-assertion": "error",
    "@typescript-eslint/no-unused-vars": [
      "error",
      {
        args: "after-used",
        argsIgnorePattern: "^_",
        ignoreRestSiblings: true,
        vars: "all",
        varsIgnorePattern: "^_",
      },
    ],
    "@typescript-eslint/prefer-optional-chain": "error",

    /* Standard ESLint rules */
    "arrow-parens": ["error", "as-needed"],
    "comma-dangle": ["error", "always-multiline"],
    "max-classes-per-file": "off", // Component and ComponentItem support
    "no-console": [
      "error",
      {
        allow: ["error"],
      },
    ],
    "no-multiple-empty-lines": "error",
    "no-unused-vars": "off", // TypeScript brings its own
    "object-shorthand": ["error", "always"],
    "prefer-const": [
      "error",
      {
        destructuring: "all",
      },
    ],
    "quote-props": ["error", "as-needed"],
    quotes: [
      "error",
      "double",
      {
        avoidEscape: true,
      },
    ],
    semi: ["error", "never"],
    "sort-imports": [
      "error",
      {
        ignoreCase: true,
        ignoreDeclarationSort: true,
        ignoreMemberSort: false,
      },
    ],
    "sort-keys": "off", // We use a custom sorter that enforces shorthand-first keys

    /* import/export rules */
    "import/default": "off", // Let TypeScript sort this out
    "import/export": "error",
    "import/first": "error", // Use custom import/order grouping rather than enforcing a single group
    "import/named": "off", // Let TypeScript sort this out
    "import/namespace": "error",
    "import/no-default-export": "error",
    "import/no-duplicates": "error",
    "import/no-extraneous-dependencies": "off",
    "import/no-named-as-default": "error",
    "import/no-named-as-default-member": "error",
    "import/no-unresolved": "error",
    "import/order": [
      "error",
      {
        alphabetize: {
          caseInsensitive: true,
          order: "asc",
        },
        groups: [["builtin", "external"], "internal", "index", "sibling", "parent"],
        "newlines-between": "always",
        pathGroups: [
          {
            group: "internal",
            pattern: "src/*",
          },
        ],
      },
    ],

    /* Mocha rules */
    "mocha/no-mocha-arrows": "off",

    /* Finally, miscellaneous */
    "sort-keys-shorthand/sort-keys-shorthand": [
      "error",
      "asc",
      {
        caseSensitive: true,
        natural: false,
        minKeys: 2,
        shorthand: "first",
      },
    ],
    "prettier/prettier": "error",
  },
  settings: {
    "import/parsers": {
      "@typescript-eslint/parser": [".ts", ".tsx"],
    },
    "import/resolver": {
      typescript: {
        alwaysTryTypes: true,
        project: ["./tsconfig.json"],
      },
    },
  },
}
