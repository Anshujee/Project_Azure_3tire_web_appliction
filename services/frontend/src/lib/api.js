const BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

async function apiFetch(path, options = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(err.error || `HTTP ${res.status}`);
  }

  return res.json();
}

export const getProducts = (category) =>
  apiFetch(`/api/products${category ? `?category=${category}` : ''}`);

export const getProduct = (id) =>
  apiFetch(`/api/products/${id}`);

export const getCart = (userId) =>
  apiFetch(`/api/cart/${userId}`);

export const addToCart = (userId, item) =>
  apiFetch(`/api/cart/${userId}/items`, { method: 'POST', body: JSON.stringify(item) });

export const removeFromCart = (userId, itemId) =>
  apiFetch(`/api/cart/${userId}/items/${itemId}`, { method: 'DELETE' });

export const login = (email, password) =>
  apiFetch('/api/users/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });

export const register = (email, password, name) =>
  apiFetch('/api/users/auth/register', { method: 'POST', body: JSON.stringify({ email, password, name }) });

export const placeOrder = (order) =>
  apiFetch('/api/orders', { method: 'POST', body: JSON.stringify(order) });

export const getOrders = (userId) =>
  apiFetch(`/api/orders/user/${userId}`);
