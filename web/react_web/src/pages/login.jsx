import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { callAPI } from '../api';
import styles from '../styles/login.module.css';

const Login = () => {
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError('');

    try {
      const response = await callAPI('/login', 'POST', { password });
      if (response && response.success) {
        navigate('/students');
      } else {
        setError('로그인 실패!');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
      console.error(err);
    }
  };

  return (
    <div className={styles.container}>
      <h1 className={styles.title}>매아리</h1>
      <form onSubmit={handleSubmit} className={styles.loginForm}>
        <h2 className={styles.subtitle}>로그인</h2>
        <div>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="비밀번호를 입력하세요"
            required
            className={styles.input}
          />
        </div>
        <button type="submit" className={styles.button}>로그인</button>
      </form>
      {error && <p style={{ color: 'red', marginTop: '1rem' }}>{error}</p>}
    </div>
  );
};

export default Login;
