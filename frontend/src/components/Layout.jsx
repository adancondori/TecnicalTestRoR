const Layout = ({ children }) => {
  return (
    <>
      <nav className="navbar navbar-expand-lg navbar-dark bg-dark">
        <div className="container">
          <a className="navbar-brand" href="/">Technical Test</a>
        </div>
      </nav>

      <div className="container">
        {children}
      </div>
    </>
  );
};

export default Layout;
