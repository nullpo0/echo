import React, { useState, useEffect } from 'react';
// import { callAPI } from '../api'; // No longer needed for fetching student details
import styles from '../styles/DiaryStudentInfo.module.css';

const DiaryStudentInfo = ({ s_id, initialName, initialDangerMean }) => {
  const [name, setName] = useState(initialName);
  const [dangerMean, setDangerMean] = useState(initialDangerMean);
  const [memo, setMemo] = useState('');

  // Update state if initial props change (e.g., navigating to a different student)
  useEffect(() => {
    setName(initialName);
    setDangerMean(initialDangerMean);
    setMemo(''); // Reset memo when student changes
  }, [initialName, initialDangerMean]);

  const handleSaveMemo = () => {
    // Implement API call to save memo
    console.log(`Saving memo for student ${s_id}: ${memo}`);
    // await callAPI(`/update_std_memo/${s_id}`, 'POST', { memo });
  };

  if (!name || dangerMean === undefined) {
    return <div className={styles.container}>학생 정보를 불러오는 중...</div>;
  }

  const getDangerClass = (danger_mean) => {
    if (danger_mean >= 80) {
      return styles.dangerText;
    } else if (danger_mean >= 50) {
      return styles.warningText;
    } else {
      return styles.safeText;
    }
  };

  return (
    <div className={styles.container}>
      <h2 className={styles.name}>{name}</h2>
      <p className={styles.avgDanger}>평균 위험도: <span className={getDangerClass(dangerMean)}>{dangerMean.toFixed(1)}</span></p>
      <div className={styles.memoSection}>
        <textarea
          value={memo}
          onChange={(e) => setMemo(e.target.value)}
          placeholder="메모를 입력하세요..."
          className={styles.memoInput}
        />
        <button onClick={handleSaveMemo} className={styles.saveButton}>메모 저장</button>
      </div>
    </div>
  );
};

export default DiaryStudentInfo;
