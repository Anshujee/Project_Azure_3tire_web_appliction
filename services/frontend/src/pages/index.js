import { useState, useEffect } from 'react';
import { getProducts, addToCart } from '../lib/api';

export default function Home() {
  const [products, setProducts] = useState([]);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getProducts()
      .then(setProducts)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  const handleAddToCart = async (product) => {
    const userId = localStorage.getItem('userId') || 'guest';
    await addToCart(userId, {
      itemId: `${product.id}-${Date.now()}`,
      productId: product.id,
      name: product.name,
      price: product.price,
      quantity: 1,
    }).catch(console.error);
  };

  if (loading) return <p>Loading products...</p>;
  if (error) return <p>Error: {error}</p>;

  return (
    <div>
      <h1>AzureShop</h1>
      <div>
        {products.map((p) => (
          <div key={p.id}>
            <h2>{p.name}</h2>
            <p>{p.description}</p>
            <p>${p.price}</p>
            <button onClick={() => handleAddToCart(p)}>Add to Cart</button>
          </div>
        ))}
      </div>
    </div>
  );
}
