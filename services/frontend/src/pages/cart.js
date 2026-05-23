import { useState, useEffect } from 'react';
import Link from 'next/link';
import { getCart, removeFromCart, placeOrder } from '../lib/api';

export default function CartPage() {
  const [cart, setCart] = useState({ items: [] });
  const [loading, setLoading] = useState(true);
  const [ordered, setOrdered] = useState(false);
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
    setOrdered(true);
    setCart({ items: [] });
  };

  if (loading) return <div className="state-box">Loading cart...</div>;

  if (ordered) return (
    <div className="container">
      <div className="empty-cart">
        <div style={{ fontSize: '3rem' }}>✅</div>
        <h2 style={{ margin: '1rem 0', color: '#0078D4' }}>Order Placed!</h2>
        <p>Thank you for your purchase.</p>
        <Link href="/" className="btn-primary" style={{ display: 'inline-block', marginTop: '1.5rem', textDecoration: 'none' }}>
          Continue Shopping
        </Link>
      </div>
    </div>
  );

  const total = cart.items.reduce((sum, i) => sum + i.price * i.quantity, 0);
  const shipping = total > 0 ? 9.99 : 0;

  if (cart.items.length === 0) return (
    <div className="container">
      <div className="empty-cart">
        <div style={{ fontSize: '3rem' }}>🛒</div>
        <p>Your cart is empty</p>
        <Link href="/" className="btn-primary" style={{ display: 'inline-block', marginTop: '1rem', textDecoration: 'none' }}>
          Browse Products
        </Link>
      </div>
    </div>
  );

  return (
    <div className="container">
      <h2 className="page-title">Your Cart ({cart.items.length} item{cart.items.length !== 1 ? 's' : ''})</h2>
      <div className="cart-layout">
        <div className="cart-items">
          <div className="cart-header">Order Items</div>
          {cart.items.map((item, i) => (
            <div key={item.itemId} className="cart-item">
              <div className="cart-item-icon">
                {['💻','🖱️','⌨️','🔌','🖥️'][i % 5]}
              </div>
              <div className="cart-item-details">
                <div className="cart-item-name">{item.name}</div>
                <div className="cart-item-qty">Qty: {item.quantity}</div>
              </div>
              <div className="cart-item-price">${(item.price * item.quantity).toFixed(2)}</div>
              <button className="btn-remove" onClick={() => handleRemove(item.itemId)}>Remove</button>
            </div>
          ))}
        </div>

        <div className="cart-summary">
          <h3>Order Summary</h3>
          <div className="summary-row">
            <span>Subtotal</span>
            <span>${total.toFixed(2)}</span>
          </div>
          <div className="summary-row">
            <span>Shipping</span>
            <span>${shipping.toFixed(2)}</span>
          </div>
          <div className="summary-total">
            <span>Total</span>
            <span>${(total + shipping).toFixed(2)}</span>
          </div>
          <button className="btn-checkout" onClick={handleCheckout}>
            Place Order
          </button>
        </div>
      </div>
    </div>
  );
}
