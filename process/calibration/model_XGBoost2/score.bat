c:
cd c:\Temp\process\calibration\model_XGBoost2\
call del outscore.csv
call c:\karol\python\venvXGB\Scripts\activate.bat

c:\karol\python\venvXGB\Scripts\python.exe score.py > python.log
