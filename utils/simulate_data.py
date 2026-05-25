"""
ACS Child Welfare Data Simulation
Generates realistic synthetic datasets for learning purposes.
Run this to regenerate all data files.
"""
import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta

def simulate_acs_data(n=1000, seed=42):
    np.random.seed(seed)
    random.seed(seed)

    BOROUGHS = ['Bronx','Brooklyn','Manhattan','Queens','Staten Island']
    BOROUGH_W = [0.30,0.28,0.18,0.18,0.06]
    REPORTERS = ['School/Educational Staff','Hospital/Medical','Shelter Staff',
                 'Law Enforcement','Daycare/Childcare','Anonymous',
                 'Family Member','Neighbor/Community','Social Service Provider']
    REPORTER_W = [0.28,0.18,0.12,0.10,0.08,0.10,0.07,0.04,0.03]
    ALLEGATIONS = ['Neglect - Educational','Neglect - Inadequate Supervision',
                   'Neglect - Inadequate Food/Clothing/Shelter','Physical Abuse',
                   'Emotional Abuse','Sexual Abuse','Neglect - Medical',
                   'Domestic Violence Exposure']
    ALLEG_W = [0.20,0.22,0.18,0.15,0.08,0.05,0.07,0.05]
    OUTCOMES = ['Unsubstantiated','Substantiated','Unfounded','Still Open']
    RACE = ['Black/African American','Hispanic/Latino','White','Asian','Multiracial','Unknown']
    RACE_W = [0.38,0.32,0.15,0.04,0.05,0.06]

    start = datetime(2021,1,1)
    end   = datetime(2024,12,31)
    dates = [start + timedelta(days=random.randint(0,(end-start).days)) for _ in range(n)]
    fam_ids = [f'FAM{str(i).zfill(5)}' for i in range(1,651)]
    report_fams = np.random.choice(fam_ids, size=n)
    ages = np.random.choice(range(18), size=n,
           p=[0.08,0.08,0.07,0.07,0.07,0.06,0.06,0.06,0.06,
              0.05,0.05,0.05,0.05,0.04,0.04,0.04,0.04,0.03])
    boroughs   = np.random.choice(BOROUGHS, size=n, p=BOROUGH_W)
    reporters  = np.random.choice(REPORTERS, size=n, p=REPORTER_W)
    allegations= np.random.choice(ALLEGATIONS, size=n, p=ALLEG_W)
    races      = np.random.choice(RACE, size=n, p=RACE_W)
    prior_rpts = np.clip(np.random.negative_binomial(1,0.6,size=n),0,8)
    prior_subst= np.random.binomial(1,0.22,size=n)
    days_last  = np.where(prior_rpts>0, np.random.randint(1,365,size=n), np.nan)
    n_children = np.random.choice([1,2,3,4,5],size=n,p=[0.30,0.35,0.20,0.10,0.05])
    dv_hist    = np.random.binomial(1,0.28,size=n)
    substance  = np.where(np.random.binomial(1,0.15,size=n)==1, np.nan,
                          np.random.binomial(1,0.31,size=n))
    shelter    = np.random.binomial(1,0.18,size=n)
    rep_acc_map= {'School/Educational Staff':0.31,'Hospital/Medical':0.42,
                  'Shelter Staff':0.28,'Law Enforcement':0.38,
                  'Daycare/Childcare':0.35,'Anonymous':0.14,
                  'Family Member':0.22,'Neighbor/Community':0.18,
                  'Social Service Provider':0.33}
    rep_acc    = np.clip([rep_acc_map[r]+np.random.normal(0,0.05) for r in reporters],0,1)
    caseload   = np.random.randint(30,80,size=n)
    contact    = np.where(np.random.binomial(1,0.08,size=n)==1, np.nan,
                          np.random.exponential(2,size=n).astype(int)+1)
    log_odds   = (-2.5+0.4*prior_rpts+0.8*prior_subst+0.5*dv_hist+0.3*shelter
                  +np.where(ages<5,0.6,0)
                  +np.where(np.array(allegations)=='Physical Abuse',0.7,0)
                  +np.where(np.array(allegations)=='Sexual Abuse',0.9,0)
                  +np.where(np.array(reporters)=='Hospital/Medical',0.3,0)
                  +np.where(substance==1,0.4,0)+np.random.normal(0,0.5,size=n))
    prob       = 1/(1+np.exp(-log_odds))
    needs_cons = np.random.binomial(1,prob)
    outcomes   = np.where(np.random.binomial(1,0.10,size=n)==1,'Still Open',
                          np.random.choice(OUTCOMES[:3],size=n,p=[0.53,0.31,0.16]))
    cw_ids     = [f'CW{str(i).zfill(4)}' for i in np.random.randint(1,80,size=n)]

    NARR = [
        'Reporter states child appeared disheveled and hungry. Child reported parent unable to be reached.',
        'Medical staff observed bruising during checkup. Child disclosed hitting at home.',
        'Neighbor reports child unsupervised for extended periods. Child left alone overnight.',
        'Law enforcement responded to domestic incident. Child present in home.',
        'Shelter staff reports family in crisis. Caregiver appeared intoxicated.',
        'Anonymous caller reports child home alone. No food observed in home.',
    ]
    narratives = [random.choice(NARR) for _ in range(n)]

    scr = pd.DataFrame({
        'report_id':         [f'SCR{str(i).zfill(6)}' for i in range(1,n+1)],
        'family_id':          report_fams,
        'report_date':        dates,
        'borough':            boroughs,
        'child_age':          ages,
        'child_race_ethnicity': races,
        'allegation_type':    allegations,
        'reporter_type':      reporters,
        'reporter_accuracy_score': np.round(rep_acc,3),
        'assigned_caseworker_id': cw_ids,
        'caseworker_caseload': caseload,
        'narrative':          narratives,
        'outcome':            outcomes,
    })

    features = pd.DataFrame({
        'report_id':                   scr['report_id'],
        'family_id':                   scr['family_id'],
        'prior_reports_12mo':          prior_rpts,
        'prior_substantiated_flag':    prior_subst,
        'days_since_last_report':      days_last,
        'n_children_in_household':     n_children,
        'child_age_under_5':           (ages<5).astype(int),
        'dv_history_flag':             dv_hist,
        'substance_use_flag':          substance,
        'shelter_involvement_flag':    shelter,
        'days_to_first_contact':       contact,
        'reporter_accuracy_score':     np.round(rep_acc,3),
        'caseworker_caseload':         caseload,
        'needs_investigative_consultation': needs_cons,
    })

    return scr, features

if __name__ == '__main__':
    scr, features = simulate_acs_data()
    scr.to_csv('data/acs_scr_reports.csv', index=False)
    features.to_csv('data/acs_features.csv', index=False)
    print(f'Generated: {len(scr)} SCR reports, {len(features)} feature rows')
