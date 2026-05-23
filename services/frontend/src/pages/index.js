import { useState, useEffect } from 'react';
import { getProducts, addToCart } from '../lib/api';

const PRODUCT_ICONS = ['💻', '🖱️', '⌨️', '🔌', '🖥️', '📱', '🎧', '📷'];

export default function Home() {
  const [products, setProducts] = useState([]);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState(null);

  useEffect(() => {
    getProducts()
      .then(setProducts)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  const showToast = (msg) => {
    setToast(msg);
    setTimeout(() => setToast(null), 2500);
  };

  const handleAddToCart = async (product) => {
    const userId = localStorage.getItem('userId') || 'guest';
    try {
      await addToCart(userId, {
        itemId: `${product.id}-${Date.now()}`,
        productId: product.id,
        name: product.name,
        price: product.price,
        quantity: 1,
      });
      showToast(`✓ ${product.name} added to cart`);
    } catch {
      showToast('Failed to add item');
    }
  };

  if (loading) return <div className="state-box">Loading products...</div>;
  if (error)   return <div className="state-box" style={{ color: '#cc0000' }}>Error: {error}</div>;

  return (
    <div className="container">
      <div className="hero">
        <h1>Welcome to AzureShop</h1>
        <p>Premium tech products — cloud-powered, developer-built</p>
      </div>

      <h2 className="page-title">All Products</h2>

      <div className="products-grid">
        {products.map((p, i) => (
          <div key={p.id} className="product-card">
            <div className="product-image">
              {PRODUCT_ICONS[i % PRODUCT_ICONS.length]}
            </div>
            <div className="product-info">
              <div className="product-name">{p.name}</div>
              <div className="product-desc">{p.description}</div>
              <div className="product-footer">
                <span className="product-price">${p.price.toFixed(2)}</span>
                <button className="btn-primary" onClick={() => handleAddToCart(p)}>
                  Add to Cart
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}
