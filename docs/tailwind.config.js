/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./src/**/*.jl"
    ],
    darkMode: 'class',
    theme: {
        extend: {
            fontFamily: {
                sans: ['Source Sans 3', 'system-ui', 'sans-serif'],
                serif: ['Lora', 'Georgia', 'Cambria', 'serif'],
            }
        }
    },
    plugins: [],
}
