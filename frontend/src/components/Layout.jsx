import { Outlet, Link } from "react-router-dom";

const Layout = () => {
  return (
    <>
      <div>
        <nav className="navbar navbar-expand-lg navbar-light" style={{ backgroundColor: '#496989' }}>
          <div className="container">
            <Link className="navbar-brand" to="/" style={{ color: '#FFFFFF' }}>Mi Sitio</Link>
            <button className="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
              <span className="navbar-toggler-icon"></span>
            </button>
            <div className="collapse navbar-collapse" id="navbarNav">
              <ul className="navbar-nav">
                <li className="nav-item">
                  <Link className="nav-link" to="/features" style={{ color: '#b5e2f8' }}>Features</Link>
                </li>
              </ul>
            </div>
          </div>
        </nav>

        <div className="container">
          <Outlet />
        </div>
      </div>

    </>
  )
};

export default Layout;