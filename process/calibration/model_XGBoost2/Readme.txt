How to run configure and XGBoosting model PD_CSS

1. Create Python virtual environment venvXGB
a. Follow by commands in commands_XGBoosting.txt
b. Use requirementsXGB.txt as a list of Python packages
2. Update paths in score.bat
a. One path is to your folder with scoring_code.sas
b. Second path is to Python.exe from your virtual environment
c. The idea is to run command “x”, invocation of any program in Windows system
3. Make some trials by the code: test_calibration.sas
a. The most important lines:
%let zbior=cal;
%let scoring_dir=&dir.process\calibration\model_XGBoost2\;
%include "&scoring_dir.scoring_code.sas";
4. Prepare the final code for calibration, see: calibration.sas
5. Update rules and some lines in decision engine: decision_engine.sas
6. After running all_contents.sas you will get the results, see: profit_1975_1987.html
7. The usage of AI model can be only for one model in the project
8. If you want to use your own AI model you need to explain your model by SHAP
a. XAI methods are very important in that case
b. To get many points during the project defense you need to prepare a proper lins of XAI reports and explain
