import '../styles/globals.css';
import Link from 'next/link';

function Navbar() {
  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('userId');
    window.location.href = '/login';
  };

  const isLoggedIn = typeof window !== 'undefined' && !!localStorage.getItem('token');

  return (
    <nav className="navbar">
      <Link href="/" className="navbar-brand">Azure<span>Shop</span></Link>
      <div className="navbar-links">
        <Link href="/">Products</Link>
        <Link href="/cart">Cart</Link>
        {isLoggedIn ? (
          <button className="btn-nav" onClick={handleLogout}>Logout</button>
        ) : (
          <Link href="/login" className="btn-nav">Sign In</Link>
        )}
      </div>
    </nav>
  );
}

export default function App({ Component, pageProps }) {
  return (
    <>
      <Navbar />
      <Component {...pageProps} />
    </>
  );
}
