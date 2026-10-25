import os
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 60))


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password_plano: str, password_hash: str) -> bool:
    return pwd_context.verify(password_plano, password_hash)


def crear_token_acceso(datos: dict, minutos: int | None = None) -> str:
    datos_copia = datos.copy()
    duracion = ACCESS_TOKEN_EXPIRE_MINUTES if minutos is None else minutos
    expiracion = datetime.now(timezone.utc) + timedelta(minutes=duracion)
    datos_copia.update({"exp": expiracion})
    return jwt.encode(datos_copia, SECRET_KEY, algorithm=ALGORITHM)


def verificar_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None