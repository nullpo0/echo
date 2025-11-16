import React from 'react';
import { Outlet } from 'react-router-dom';

const Layout = () => {
  const layoutStyle = {
    backgroundColor: '#F5F5DC', // A light brown color (beige)
    minHeight: '100vh',
    padding: '20px',
  };

  return (
    <div style={layoutStyle}>
      <Outlet />
    </div>
  );
};

export default Layout;
