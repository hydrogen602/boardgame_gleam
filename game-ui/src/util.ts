import { useCallback, useState } from "react";

export function useLocalStorage<T>(initialValue: T, key: string): [T, (value: T) => void] {
  const [state, setStateRaw] = useState<T>(() => {
    const localData = localStorage.getItem(key);
    return localData ? JSON.parse(localData) : initialValue;
  });

  const setState = useCallback((value: T) => {
    localStorage.setItem(key, JSON.stringify(value));
    setStateRaw(value);
  }, [key]);

  return [state, setState];
}