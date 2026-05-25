# ============================================================
# Child Welfare Analytics — Shiny Dashboard (Simulated Data)
# ============================================================
# Personal learning project. Uses synthetic intake records from
# ../data/. Not affiliated with ACS or any agency.
#
# Run from the repo root:  shiny::runApp("shiny_app")
# ============================================================

library(shiny)
library(shinydashboard)
library(tidyverse)
library(tidymodels)
library(ranger)
library(shapviz)
library(leaflet)
library(DT)
library(plotly)

# ─── LOAD DATA AND MODEL ──────────────────────────────────────
# shiny::runApp("shiny_app") sets wd to shiny_app/, so ../data is the repo's data dir.
# If launched from inside shiny_app/, fall back to ./data.
DATA_DIR <- if (dir.exists("../data")) "../data" else "data"

scr      <- read_csv(file.path(DATA_DIR, 'acs_scr_reports.csv'), show_col_types=FALSE) %>%
  mutate(
    report_date      = as.Date(report_date),
    is_substantiated = outcome == 'Substantiated',
    year_month       = floor_date(report_date, 'month'),
    allegation_severity = case_when(
      allegation_type == 'Sexual Abuse'    ~ 5,
      allegation_type == 'Physical Abuse'  ~ 4,
      TRUE                                 ~ 1
    )
  )

features <- read_csv(file.path(DATA_DIR, 'acs_features.csv'), show_col_types=FALSE)

FEATURES <- c('prior_reports_12mo','prior_substantiated_flag',
               'dv_history_flag','child_age_under_5',
               'shelter_involvement_flag','reporter_accuracy_score',
               'caseworker_caseload','n_children_in_household')

# Train quick model for demo
set.seed(42)
model_data <- features %>%
  mutate(
    target = factor(needs_investigative_consultation,
                    levels=c(0,1), labels=c('No','Yes'))
  ) %>%
  drop_na(all_of(c(FEATURES,'target')))

rf_model <- ranger(
  target ~ .,
  data        = model_data %>% select(all_of(c(FEATURES,'target'))),
  num.trees   = 100,
  probability = TRUE,
  seed        = 42
)

# Predictions on all data
X_all      <- model_data %>% select(all_of(FEATURES)) %>% as.data.frame()
model_data$risk_score <- predict(rf_model, X_all)$predictions[,'Yes']

# SHAP values
shp        <- shapviz(rf_model, X_pred=X_all, X=X_all)

# Full dataset for dashboard
dashboard_data <- scr %>%
  left_join(model_data %>% select(report_id, risk_score), by='report_id') %>%
  mutate(
    risk_tier = case_when(
      risk_score >= 0.70 ~ 'HIGH',
      risk_score >= 0.40 ~ 'MEDIUM',
      TRUE               ~ 'LOW'
    ),
    risk_tier = factor(risk_tier, levels=c('HIGH','MEDIUM','LOW'))
  )

# ─── UI ───────────────────────────────────────────────────────
ui <- dashboardPage(
  skin = 'blue',

  dashboardHeader(
    title = 'Child Welfare Analytics (Simulated)',
    titleWidth = 280
  ),

  dashboardSidebar(
    width = 280,
    sidebarMenu(
      menuItem('ChildStat Overview',  tabName='overview',   icon=icon('chart-bar')),
      menuItem('Reporter Analysis',   tabName='reporter',   icon=icon('phone')),
      menuItem('Risk Model',          tabName='risk',       icon=icon('exclamation-triangle')),
      menuItem('SHAP Explainability', tabName='shap',       icon=icon('search')),
      menuItem('Fairness Audit',      tabName='fairness',   icon=icon('balance-scale'))
    ),
    hr(),
    selectInput('borough_filter', 'Borough:',
      choices=c('All', sort(unique(scr$borough))), selected='All'),
    dateRangeInput('date_filter', 'Date Range:',
      start=min(scr$report_date), end=max(scr$report_date)),
    sliderInput('threshold', 'Risk Threshold:', 0.1, 0.9, 0.4, step=0.05)
  ),

  dashboardBody(
    tags$head(tags$style(HTML('.content-wrapper { background-color: #f4f6f9; }'))),

    tabItems(

      # ── TAB 1: ChildStat Overview ──────────────────────────
      tabItem(tabName='overview',
        fluidRow(
          valueBoxOutput('box_total',    width=3),
          valueBoxOutput('box_subst',    width=3),
          valueBoxOutput('box_high_risk',width=3),
          valueBoxOutput('box_avg_age',  width=3)
        ),
        fluidRow(
          box(plotlyOutput('borough_chart'), width=6,
              title='Reports by Borough', status='primary', solidHeader=TRUE),
          box(plotlyOutput('trend_chart'), width=6,
              title='Monthly Trend', status='primary', solidHeader=TRUE)
        ),
        fluidRow(
          box(plotlyOutput('allegation_chart'), width=6,
              title='Allegation Types', status='warning', solidHeader=TRUE),
          box(plotlyOutput('heatmap_chart'), width=6,
              title='Allegation × Borough Heatmap', status='warning', solidHeader=TRUE)
        )
      ),

      # ── TAB 2: Reporter Analysis (ChildStat) ───────────────
      tabItem(tabName='reporter',
        fluidRow(
          box(
            sliderInput('min_reports_r', 'Min Reports:', 1, 50, 5),
            width=12,
            title='Filter Settings', status='info'
          )
        ),
        fluidRow(
          box(plotlyOutput('reporter_accuracy_chart'), width=7,
              title='Reporter Accuracy by Type', status='danger', solidHeader=TRUE),
          box(DTOutput('reporter_table'), width=5,
              title='Reporter Summary Table', status='info', solidHeader=TRUE)
        )
      ),

      # ── TAB 3: Risk Model ───────────────────────────────────
      tabItem(tabName='risk',
        fluidRow(
          valueBoxOutput('box_flagged',   width=4),
          valueBoxOutput('box_precision', width=4),
          valueBoxOutput('box_recall',    width=4)
        ),
        fluidRow(
          box(plotlyOutput('risk_dist'), width=6,
              title='Risk Score Distribution', status='danger', solidHeader=TRUE),
          box(plotlyOutput('threshold_chart'), width=6,
              title='Threshold: Precision vs Recall', status='warning', solidHeader=TRUE)
        ),
        fluidRow(
          box(DTOutput('high_risk_table'), width=12,
              title='Highest Risk Cases', status='danger', solidHeader=TRUE)
        )
      ),

      # ── TAB 4: SHAP ─────────────────────────────────────────
      tabItem(tabName='shap',
        fluidRow(
          box(plotOutput('shap_importance'), width=6,
              title='Global Feature Importance (SHAP)', status='primary', solidHeader=TRUE),
          box(
            numericInput('case_idx', 'Case Index for Waterfall:', 1, min=1, max=200),
            plotOutput('shap_waterfall'),
            width=6, title='Per-Case SHAP Waterfall', status='success', solidHeader=TRUE
          )
        )
      ),

      # ── TAB 5: Fairness Audit ───────────────────────────────
      tabItem(tabName='fairness',
        fluidRow(
          box(plotlyOutput('fairness_fpr'), width=6,
              title='False Positive Rate by Borough', status='danger', solidHeader=TRUE),
          box(plotlyOutput('fairness_recall'), width=6,
              title='Recall by Borough', status='success', solidHeader=TRUE)
        ),
        fluidRow(
          box(DTOutput('fairness_table'), width=12,
              title='Fairness Metrics by Borough',
              footer='Demo only on synthetic data — large between-group FPR gaps would warrant an equity review on real data.',
              status='warning', solidHeader=TRUE)
        )
      )
    )
  )
)

# ─── SERVER ───────────────────────────────────────────────────
server <- function(input, output, session) {

  # Reactive filtered data
  filtered <- reactive({
    d <- dashboard_data %>%
      filter(report_date >= input$date_filter[1],
             report_date <= input$date_filter[2])
    if(input$borough_filter != 'All')
      d <- d %>% filter(borough == input$borough_filter)
    d
  })

  # ── VALUE BOXES ─────────────────────────────────────────────
  output$box_total <- renderValueBox({
    valueBox(format(nrow(filtered()), big.mark=','),
             'Total Reports', icon=icon('file'), color='blue')
  })
  output$box_subst <- renderValueBox({
    r <- round(mean(filtered()$is_substantiated, na.rm=TRUE)*100,1)
    valueBox(paste0(r,'%'), 'Substantiation Rate',
             icon=icon('check'), color='green')
  })
  output$box_high_risk <- renderValueBox({
    n <- sum(filtered()$risk_tier=='HIGH', na.rm=TRUE)
    valueBox(n, 'High Risk Cases', icon=icon('exclamation'), color='red')
  })
  output$box_avg_age <- renderValueBox({
    a <- round(mean(filtered()$child_age, na.rm=TRUE),1)
    valueBox(a, 'Avg Child Age', icon=icon('child'), color='purple')
  })

  # ── TAB 1 CHARTS ────────────────────────────────────────────
  output$borough_chart <- renderPlotly({
    p <- filtered() %>% count(borough) %>%
      mutate(borough=fct_reorder(borough,n)) %>%
      ggplot(aes(x=borough, y=n, fill=borough,
                 text=paste('Borough:',borough,'<br>Reports:',n))) +
      geom_col(show.legend=FALSE) + coord_flip() +
      labs(x=NULL, y='Reports') + theme_minimal()
    ggplotly(p, tooltip='text')
  })

  output$trend_chart <- renderPlotly({
    p <- filtered() %>%
      count(year_month) %>%
      ggplot(aes(x=year_month, y=n)) +
      geom_line(color='steelblue', linewidth=1) +
      geom_smooth(method='loess', se=FALSE, color='red', linetype='dashed') +
      labs(x=NULL, y='Reports/Month') + theme_minimal()
    ggplotly(p)
  })

  output$allegation_chart <- renderPlotly({
    p <- filtered() %>% count(allegation_type) %>%
      mutate(allegation_type=fct_reorder(allegation_type,n)) %>%
      ggplot(aes(x=allegation_type, y=n, fill=allegation_type,
                 text=paste(allegation_type,':', n))) +
      geom_col(show.legend=FALSE) + coord_flip() +
      labs(x=NULL,y='Count') + theme_minimal()
    ggplotly(p, tooltip='text')
  })

  output$heatmap_chart <- renderPlotly({
    p <- filtered() %>%
      count(borough, allegation_type) %>%
      group_by(borough) %>%
      mutate(pct=round(n/sum(n)*100,1)) %>%
      ggplot(aes(x=borough, y=allegation_type, fill=pct,
                 text=paste0(borough,'\n',allegation_type,'\n',pct,'%'))) +
      geom_tile(color='white') +
      scale_fill_gradient(low='#EFF3FF', high='#2171B5') +
      labs(x=NULL,y=NULL) + theme_minimal() +
      theme(axis.text.x=element_text(angle=30,hjust=1))
    ggplotly(p, tooltip='text')
  })

  # ── TAB 2: REPORTER ─────────────────────────────────────────
  output$reporter_accuracy_chart <- renderPlotly({
    p <- filtered() %>%
      group_by(reporter_type) %>%
      summarise(n=n(), rate=round(mean(is_substantiated,na.rm=TRUE)*100,1)) %>%
      filter(n >= input$min_reports_r) %>%
      mutate(reporter_type=fct_reorder(reporter_type,rate)) %>%
      ggplot(aes(x=reporter_type, y=rate, fill=rate,
                 text=paste0(reporter_type,'\nRate: ',rate,'%\nn=',n))) +
      geom_col(show.legend=FALSE) + coord_flip() +
      scale_fill_gradient(low='#FEE5D9',high='#A50F15') +
      labs(x=NULL,y='Substantiation Rate (%)') + theme_minimal()
    ggplotly(p, tooltip='text')
  })

  output$reporter_table <- renderDT({
    filtered() %>%
      group_by(reporter_type) %>%
      summarise(
        Reports=n(),
        Subst_Rate=paste0(round(mean(is_substantiated,na.rm=TRUE)*100,1),'%')
      ) %>%
      arrange(desc(Reports)) %>%
      datatable(options=list(pageLength=8, dom='t'), rownames=FALSE)
  })

  # ── TAB 3: RISK MODEL ───────────────────────────────────────
  thresh_data <- reactive({
    d <- filtered() %>% filter(!is.na(risk_score))
    map_dfr(seq(0.2, 0.7, 0.05), function(t) {
      pred <- d$risk_score >= t
      actual <- d$is_substantiated
      tp <- sum(pred & actual, na.rm=TRUE)
      fp <- sum(pred & !actual, na.rm=TRUE)
      fn <- sum(!pred & actual, na.rm=TRUE)
      tn <- sum(!pred & !actual, na.rm=TRUE)
      tibble(
        threshold=t,
        recall=round(tp/(tp+fn+0.001),3),
        precision=round(tp/(tp+fp+0.001),3),
        flagged=sum(pred)
      )
    })
  })

  output$box_flagged <- renderValueBox({
    n <- sum(filtered()$risk_score >= input$threshold, na.rm=TRUE)
    valueBox(n, paste0('Flagged (≥',input$threshold,')'),
             icon=icon('flag'), color='red')
  })

  output$risk_dist <- renderPlotly({
    p <- filtered() %>% filter(!is.na(risk_score)) %>%
      ggplot(aes(x=risk_score, fill=risk_tier)) +
      geom_histogram(bins=30, color='white', alpha=0.85) +
      geom_vline(xintercept=input$threshold, linetype='dashed',
                 color='black', linewidth=1) +
      scale_fill_manual(values=c(HIGH='#CB181D',MEDIUM='#FD8D3C',LOW='#2171B5')) +
      labs(x='Risk Score', y='Count', fill='Risk Tier') + theme_minimal()
    ggplotly(p)
  })

  output$threshold_chart <- renderPlotly({
    p <- thresh_data() %>%
      pivot_longer(c(recall,precision), names_to='metric', values_to='value') %>%
      ggplot(aes(x=threshold, y=value, color=metric)) +
      geom_line(linewidth=1) +
      geom_vline(xintercept=input$threshold, linetype='dashed') +
      scale_color_manual(values=c(recall='#CB181D',precision='#2171B5')) +
      labs(x='Threshold', y='Score', color='Metric') + theme_minimal()
    ggplotly(p)
  })

  output$high_risk_table <- renderDT({
    filtered() %>%
      filter(!is.na(risk_score)) %>%
      arrange(desc(risk_score)) %>%
      select(report_id, family_id, borough, allegation_type,
             reporter_type, risk_score, risk_tier) %>%
      head(50) %>%
      mutate(risk_score=round(risk_score,3)) %>%
      datatable(options=list(pageLength=10), rownames=FALSE)
  })

  # ── TAB 4: SHAP ─────────────────────────────────────────────
  output$shap_importance <- renderPlot({
    sv_importance(shp, kind='bar') +
      labs(title='Global SHAP: Average Feature Contribution') +
      theme_minimal(base_size=12)
  })

  output$shap_waterfall <- renderPlot({
    idx <- min(input$case_idx, nrow(X_all))
    sv_waterfall(shp, row_id=idx) +
      labs(title=paste('Case', idx, '— SHAP Explanation')) +
      theme_minimal(base_size=11)
  })

  # ── TAB 5: FAIRNESS ─────────────────────────────────────────
  fairness_data <- reactive({
    d <- filtered() %>% filter(!is.na(risk_score), !is.na(is_substantiated))
    d %>%
      mutate(flagged = risk_score >= input$threshold) %>%
      group_by(borough) %>%
      summarise(
        n=n(),
        positive_rate=round(mean(is_substantiated)*100,1),
        flag_rate=round(mean(flagged)*100,1),
        recall=round(sum(flagged & is_substantiated)/
                     max(sum(is_substantiated),1),3),
        fpr=round(sum(flagged & !is_substantiated)/
                  max(sum(!is_substantiated),1),3),
        .groups='drop'
      ) %>% filter(!is.na(borough))
  })

  output$fairness_fpr <- renderPlotly({
    p <- fairness_data() %>%
      mutate(borough=fct_reorder(borough,fpr)) %>%
      ggplot(aes(x=borough, y=fpr, fill=fpr,
                 text=paste0(borough,'\nFPR: ',round(fpr,3)))) +
      geom_col(show.legend=FALSE) + coord_flip() +
      scale_fill_gradient(low='#EFF3FF',high='#CB181D') +
      labs(x=NULL, y='False Positive Rate') + theme_minimal()
    ggplotly(p, tooltip='text')
  })

  output$fairness_recall <- renderPlotly({
    p <- fairness_data() %>%
      mutate(borough=fct_reorder(borough,recall)) %>%
      ggplot(aes(x=borough, y=recall, fill=recall,
                 text=paste0(borough,'\nRecall: ',round(recall,3)))) +
      geom_col(show.legend=FALSE) + coord_flip() +
      scale_fill_gradient(low='#FEE5D9',high='#238B45') +
      labs(x=NULL, y='Recall') + theme_minimal()
    ggplotly(p, tooltip='text')
  })

  output$fairness_table <- renderDT({
    fairness_data() %>%
      mutate(
        fpr_flag=ifelse(fpr>0.40,'⚠️ HIGH','✓ OK'),
        across(where(is.double), ~round(.,3))
      ) %>%
      datatable(rownames=FALSE,
                options=list(pageLength=6, dom='t'))
  })
}

shinyApp(ui, server)
