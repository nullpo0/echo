import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import './styles/global.css';

//페이지 임포트
import Login from './pages/login';
import Students from './pages/students';
import Diaries from './pages/diaries';
import Layout from './components/Layout';

const App = () => {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          {/* route 추가 */}
          <Route path='/' element={<Login />} />
          <Route path='/students' element={<Students />} />
          <Route path='/diaries/:s_id' element={<Diaries />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
};

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
