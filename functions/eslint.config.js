const js = require("@eslint/js");

module.exports = [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
      globals: {
        exports: "writable",
        fetch: "readonly",
        require: "readonly",
        URL: "readonly",
      },
    },
  },
];
