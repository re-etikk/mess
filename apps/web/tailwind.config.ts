import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/**/*.{js,ts,jsx,tsx,mdx}",
    "./apps/web/src/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        cream: {
          50: '#FDFBF7',
          100: '#F8F4EB',
          200: '#EDE4D1',
        },
        navy: {
          800: '#1E293B',
          900: '#0F172A',
          950: '#020617',
        },
        saffron: {
          500: '#F97316',
          600: '#EA580C',
          700: '#C2410C',
        },
        tiffin: {
          green: '#16A34A',
          greenLight: '#DCFCE7',
          greenDark: '#15803D',
        }
      },
    },
  },
  plugins: [],
};
export default config;
