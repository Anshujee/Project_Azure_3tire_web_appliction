import { useState, useEffect } from 'react';
import { getCart, removeFromCart, placeOrder } from '../lib/api';

export default function CartPage() {
  const [cart, setCart] = useState({ items: [] });
  const [loading, setLoading] = useState(true);
  const userId = typeof window !== 'undefined' ? localStorage.getItem('userId') || 'guest' : 'guest';

  useEffect(() => {
    getCart(userId)
      .then(setCart)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [userId]);

  const handleRemove = async (itemId) => {
    await removeFromCart(userId, itemId).catch(console.error);
    setCart((prev) => ({ ...prev, items: prev.items.filter((i) => i.itemId !== itemId) }));
  };

  const handleCheckout = async () => {
    const total = cart.items.reduce((sum, i) => sum + i.price * i.quantity, 0);
    await placeOrder({ userId, items: cart.items, totalAmount: total }).catch(console.error);
    alert('Order placed!');
  };

  if (loading) return <p>Loading cart...</p>;

  const total = cart.items.reduce((sum, i) => sum + i.price * i.quantity, 0);

  return (
    <div>
      <h1>Your Cart</h1>
      {cart.items.length === 0 ? (
        <p>Cart is empty</p>
      ) : (
        <>
          {cart.items.map((item) => (
            <div key={item.itemId}>
              <span>{item.name} × {item.quantity} — ${item.price * item.quantity}</span>
              <button onClick={() => handleRemove(item.itemId)}>Remove</button>
            </div>
          ))}
          <p>Total: ${total.toFixed(2)}</p>
          <button onClick={handleCheckout}>Place Order</button>
        </>
      )}
    </div>
  );
}
