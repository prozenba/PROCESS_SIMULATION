# Python scoring code
def call_model():
    print("Start")
    import xgboost
    import pandas as pd
    import math
    import category_encoders as ce

    target_name='default12'
    time_name='period'
    intercept_name='Intercept'
    event_value='outstanding_bad'
    all_value='outstanding'
    id_vars=['aid']    

    df = pd.read_sas("abt_tmp.sas7bdat", encoding='LATIN2')

    #List of variables
    #     vars = [var for var in list(df) if var[0:3].lower() in ['app','act']]
    vars = [var for var in list(df) if var[0:3].lower() in ['app','act','agr','ags']]

    #Splitting into numeric and character variables
    varsc = list(df[vars].select_dtypes(include='object'))
    varsn = list(df[vars].select_dtypes(include='number'))


    #Categorical variables coding
    enc = ce.BinaryEncoder(cols=varsc)
    df_ce = enc.fit_transform(df[varsc])
    varsc_ce = list(df_ce)

    #     df_ce = enc.fit_transform(df)
    df_ce=df

    vars_ce = varsn
    #     vars_ce = varsn + varsc_ce

    test = df_ce
    test[target_name]=1

    X_test=test[vars_ce]
    Y_test=test[target_name]


    xdm_test  = xgboost.DMatrix(X_test, Y_test, enable_categorical=True, missing=True)


    model = xgboost.Booster()

    model.load_model("xgb1.model")

    Y_pred_test = model.predict(xdm_test)

    df_out=df

    df_out['SCORECARD_POINTS']= pd.DataFrame(Y_pred_test)

    fin_vars= ['SCORECARD_POINTS'] + [time_name] + id_vars

    df_out=df_out[fin_vars]

    df_out.to_csv("outscore.csv", index=False)

    print("End")
    return
call_model()
