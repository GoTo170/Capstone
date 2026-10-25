import { useEffect, useState } from 'react'

type Tema = 'light' | 'dark'

const KEY = 'mamoru_tema'

function temaInicial(): Tema {
  return localStorage.getItem(KEY) === 'dark' ? 'dark' : 'light'
}

export function useTheme() {
  const [tema, setTema] = useState<Tema>(temaInicial)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', tema)
    localStorage.setItem(KEY, tema)
  }, [tema])

  const alternar = () => setTema((actual) => (actual === 'dark' ? 'light' : 'dark'))

  return { tema, alternar }
}