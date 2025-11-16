import React, { useState, useEffect, useMemo } from 'react';
import { useParams, useLocation } from 'react-router-dom';
import Calendar from 'react-calendar';
import 'react-calendar/dist/Calendar.css';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ReferenceArea, ResponsiveContainer } from 'recharts';
import ReactMarkdown from 'react-markdown'; // Import ReactMarkdown
import { callAPI } from '../api';
import { BASE_URL } from '../api';
import Header from '../components/Header';
import DiaryStudentInfo from '../components/DiaryStudentInfo';
import styles from '../styles/diaries.module.css';

const Diaries = () => {
  const { s_id } = useParams();
  const location = useLocation();
  const { name: initialName, danger_mean: initialDangerMean } = location.state || {};

  const [diaries, setDiaries] = useState([]);
  const [selectedDate, setSelectedDate] = useState(() => new Date());
  const [comment, setComment] = useState('');
  const [analysisContent, setAnalysisContent] = useState(null); // State for analysis markdown
  const [analyzedDiaryId, setAnalyzedDiaryId] = useState(null); // State to track which diary is analyzed
  const [isLoadingAnalysis, setIsLoadingAnalysis] = useState(false); // New state for loading analysis

  const imageBaseUrl = useMemo(() => {
    return BASE_URL.endsWith('/web') ? BASE_URL.slice(0, -4) : BASE_URL;
  }, [BASE_URL]);

  useEffect(() => {
    const fetchDiaries = async () => {
      try {
        const data = await callAPI(`/get_diaries/${s_id}`, 'GET');
        if (data) {
          const formattedData = data.map(d => ({ ...d, date: new Date(d.date) }));
          setDiaries(formattedData);
        }
      } catch (error) {
        console.error("Failed to fetch diaries:", error);
      }
    };
    fetchDiaries();
  }, [s_id]);

  const selectedDiary = useMemo(() => {
    return diaries.find(d => d.date.toDateString() === selectedDate.toDateString());
  }, [diaries, selectedDate]);

  useEffect(() => {
    setComment(selectedDiary?.comment || '');
    // Reset analysis and loading state when selected diary changes
    setAnalysisContent(null);
    setAnalyzedDiaryId(null);
    setIsLoadingAnalysis(false);
  }, [selectedDiary]);

  const recentDiaries = useMemo(() => {
    const today = new Date();
    const sevenDaysAgo = new Date(today.setDate(today.getDate() - 7));
    return diaries
      .filter(d => d.date >= sevenDaysAgo)
      .sort((a, b) => a.date - b.date)
      .map(d => ({
        date: d.date.toLocaleDateString('ko-KR', { month: 'numeric', day: 'numeric' }),
        danger: d.danger,
      }));
  }, [diaries]);

  const handleDateChange = (date) => {
    setSelectedDate(date);
  };

  const getDangerClass = (danger_mean) => {
    if (danger_mean >= 80) {
      return styles.dangerText;
    } else if (danger_mean >= 50) {
      return styles.warningText;
    } else {
      return styles.safeText;
    }
  };

  const handleAnalyzeClick = async (d_id) => {
    setIsLoadingAnalysis(true); // Set loading to true
    try {
      const response = await callAPI(`/get_analysis/${d_id}`, 'GET');
      console.log("API Response for analysis:", response);
      // Check if response is an object and has a 'response' property which is a string
      if (response && typeof response.response === 'string') {
        // Replace \n with actual newline characters for markdown rendering
        setAnalysisContent(response.response.replace(/\\n/g, '\n'));
        setAnalyzedDiaryId(d_id);
      } else {
        // Handle cases where the response is not in the expected format
        setAnalysisContent('분석 결과를 불러오지 못했습니다.');
        setAnalyzedDiaryId(d_id);
      }
    } catch (error) {
      console.error("Failed to fetch analysis:", error);
      setAnalysisContent('분석 중 오류가 발생했습니다.');
      setAnalyzedDiaryId(d_id);
    } finally {
      setIsLoadingAnalysis(false); // Set loading to false regardless of outcome
    }
  };

  return (
    <div className={styles.pageContainer}>
      <Header />
      <section className={styles.topSection}>
        <div className={styles.calendarContainer}>
          <h2 className={styles.calendarTitle}>일기 선택</h2>
          <Calendar
            onChange={handleDateChange}
            value={selectedDate}
            locale="ko-KR"
          />
        </div>
        <DiaryStudentInfo s_id={s_id} initialName={initialName} initialDangerMean={initialDangerMean} />
        <div className={styles.graphContainer}>
          <h2 className={styles.graphTitle}>최근 7일 위험도</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={recentDiaries}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" />
              <YAxis domain={[0, 100]} />
              <Tooltip />
              <Legend />
              <ReferenceArea y1={80} y2={100} fill="red" fillOpacity={0.2} label="위험" />
              <ReferenceArea y1={50} y2={80} fill="yellow" fillOpacity={0.2} label="주의" />
              <ReferenceArea y1={0} y2={50} fill="green" fillOpacity={0.2} label="정상" />
              <Line type="monotone" dataKey="danger" stroke="#8884d8" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className={styles.diaryContent}>
        {selectedDiary ? (
          <div>
            <div className={styles.diaryHeader}>
              <h1 className={styles.diaryTitle}>{selectedDiary.title}</h1>
              <span className={styles.diaryDate}>{selectedDiary.date.toLocaleDateString('ko-KR')}</span>
            </div>
            <div className={styles.diaryBody}>
              {selectedDiary.img && <img src={`${imageBaseUrl}${selectedDiary.img}`} alt={selectedDiary.title} className={styles.diaryImage} />}
              <div className={styles.diaryDetails}>
                <span className={styles.caption}>일기 내용</span>
                <div className={styles.diaryTextContainer}>
                  <p className={styles.diaryText}>{selectedDiary.text}</p>
                </div>
                <span className={styles.caption}>
                  위험도: <span className={`${styles.dangerScore} ${getDangerClass(selectedDiary.danger)}`}>{selectedDiary.danger}</span>
                  {selectedDiary.danger >= 80 && (
                    <button onClick={() => handleAnalyzeClick(selectedDiary.d_id)} className={styles.analyzeButton}>상세 분석</button>
                  )}
                </span>
              </div>
            </div>
            {isLoadingAnalysis && !analysisContent && analyzedDiaryId !== selectedDiary.d_id && (
              <div className={styles.analysisLoading}>분석 중...</div>
            )}
            {analysisContent && analyzedDiaryId === selectedDiary.d_id && (
              <div className={styles.analysisSection}>
                <h3 className={styles.analysisTitle}>상세 분석 결과</h3>
                <ReactMarkdown>{analysisContent}</ReactMarkdown>
              </div>
            )}
            <div className={styles.commentSection}>
              <input
                type="text"
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                placeholder="코멘트를 입력하세요..."
                className={styles.commentInput}
              />
              <button className={styles.commentButton}>저장</button>
            </div>
          </div>
        ) : (
          <p className={styles.noDiary}>선택한 날짜에 해당하는 일기가 없습니다.</p>
        )}
      </section>
    </div>
  );
};

export default Diaries;
