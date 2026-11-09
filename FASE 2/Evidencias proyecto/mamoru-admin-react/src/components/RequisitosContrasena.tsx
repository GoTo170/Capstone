import { requisitosDe } from '../lib/contrasena'

/** Lista que se va marcando con ✓ a medida que la contraseña cumple cada requisito. */
export default function RequisitosContrasena({ valor }: { valor: string }) {
  return (
    <ul style={{ listStyle: 'none', padding: 0, margin: '8px 0 0', fontSize: '0.85rem' }}>
      {requisitosDe(valor).map((r) => (
        <li key={r.texto} style={r.ok ? { color: '#3fb68b' } : { opacity: 0.65 }}>
          {r.ok ? '✓' : '○'} {r.texto}
        </li>
      ))}
    </ul>
  )
}