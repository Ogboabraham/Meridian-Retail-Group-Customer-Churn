# Reducing Customer Churn at Meridian Retail Group

## Project Overview

This project investigates customer churn at Meridian Retail Group using an end-to-end data science workflow. The project covers data preparation, exploratory data analysis, visualization, machine learning, model explainability, and API deployment.

The objective is to identify customer characteristics and behaviors associated with churn and provide evidence-based recommendations that can support customer retention activities.

## Business Problem

Meridian Retail Group has observed lower repeat-purchase activity and increasing customer support interactions. Management wants to understand which customers are at greater risk of churn and which customer behaviors are associated with churn.

The analysis therefore focuses on:

- Identifying patterns associated with customer churn.
- Understanding purchasing and support-ticket behavior.
- Building machine-learning models that can classify customers as active or churned.
- Interpreting the most important factors associated with model predictions.
- Demonstrating how the final model could be deployed through an API.

## Dataset Description

The project uses five main datasets:

| Dataset | Raw Records | Description |
|---|---:|---|
| Customers | 6,090 | Customer demographic, membership and channel information |
| Products | 220 | Product and pricing information |
| Orders | 28,297 | Customer order transactions |
| Order Items | 73,505 | Products and quantities contained in orders |
| Support Tickets | 5,200 | Customer support interactions |

The project contains both processed and cleaned versions of the datasets.

## Project Structure

```text
Meridian Retail Group - Customer Churn Capstone/
│
├── Business Understanding/
├── Data/
│   ├── Raw Data/
│   ├── Processed Data/
│   ├── Cleaned Data/
│   ├── Phase 7 Analysis/
│   └── Phase 8 Visualization/
│
├── Phase 9 Machine Learning/
│   ├── 06_Machine_Learning/
│   ├── 07_Explainability/
│   │   └── SHAP/
│   └── Deployment/
│
└── README.md
```

## Data Quality and Cleaning

The data preparation process investigated missing values, duplicates, invalid dates, statistical outliers, inconsistent values and data types.

Key decisions included:

- Invalid customer dates of birth were converted to missing values.
- Missing dates of birth were retained as missing rather than artificially imputed.
- Revenue and transaction-value outliers were retained because they may represent legitimate high-value customers or transactions.
- Discount values within the observed valid business range were retained.
- Exact duplicate orders and order-item records were removed where identified.
- Invalid negative quantities were investigated during cleaning.
- Support-ticket dates, satisfaction scores and resolution times were validated.
- Scaling was deferred until the machine-learning stage.

## Churn Definition

Customer churn was defined using a 180-day inactivity rule.

A customer was classified as **Churned** when they had no completed order during the relevant 180-day period. Customers with qualifying recent completed orders were classified as **Active**.

The Phase 7 analysis contained:

- Churned customers: 4,072
- Active customers: 2,018

The churn target was encoded numerically as:

- 1 = Churned
- 0 = Active

## Exploratory Data Analysis

The analysis examined customer purchasing behavior, membership tiers, preferred channels and support-ticket activity.

The RFM analysis showed differences between active and churned customers, particularly in recency and purchasing behavior.

Recency was strongly associated with the churn label. However, Recency_Days was excluded from the machine-learning feature set because the 180-day churn definition is directly based on customer inactivity. Including it would introduce target leakage.

Support-ticket analysis also showed differences in churn rates across ticket-frequency groups and satisfaction-recording patterns.

## Machine Learning Approach

The machine-learning workflow included:

1. Target validation.
2. Feature selection.
3. Train/test splitting with a fixed random seed.
4. Handling class imbalance.
5. Training multiple classification models.
6. Hyperparameter tuning.
7. Model comparison.
8. Feature-importance analysis.
9. SHAP explainability.
10. Saving the final model.

### Features Used

The final feature set included:

- membership_tier
- preferred_channel
- state
- referral_source
- marketing_opt_in
- Frequency
- Monetary_Total
- Monetary_Average
- Support_Ticket_Count
- Average_Satisfaction
- Average_Resolution_Time

**Recency_Days was deliberately excluded because it is directly connected to the churn definition and could cause target leakage.**

## Model Comparison

Several models were evaluated, including Logistic Regression, Decision Tree, Random Forest, Gradient Boosting, Neural Network and ensemble approaches.

The final selected model was the **Tuned Random Forest**.

Its tuned parameters were:

- max_depth = 10
- min_samples_leaf = 5
- n_estimators = 100

The best cross-validation score during tuning was approximately 0.6279.

The final selected model achieved:

- Macro F1: 0.6234
- ROC-AUC: 0.6649

The model was selected using Macro F1 so that performance across both customer classes was considered rather than relying only on overall accuracy.

## Model Interpretation

The final Random Forest model showed that purchasing behavior was particularly important to its predictions.

The leading features were:

| Feature | Importance |
|---|---:|
| Frequency | 0.2492 |
| Monetary_Total | 0.2476 |
| Monetary_Average | 0.1515 |
| Average_Resolution_Time | 0.0609 |
| Average_Satisfaction | 0.0237 |
| Support_Ticket_Count | 0.0184 |

These results indicate that customer purchasing patterns contributed more strongly to the model than individual categorical characteristics.

SHAP analysis was also performed to provide additional explanations of individual and overall model predictions.

## Business Recommendations

Based on the analysis, Meridian Retail Group should consider:

1. Monitoring changes in customer purchasing frequency.
2. Identifying customers whose purchasing activity is declining.
3. Using customer-value information when designing retention campaigns.
4. Monitoring customers experiencing longer support-resolution times.
5. Using model predictions as a prioritization tool rather than as an automatic decision.
6. Testing targeted retention interventions and measuring their actual effect on repeat purchasing.

## False Positives and False Negatives

A false positive occurs when an active customer is incorrectly predicted to be churned. This could result in unnecessary retention offers or marketing costs.

A false negative occurs when a genuinely churned customer is predicted to be active. This could cause the company to miss an opportunity to intervene before the customer is lost.

The appropriate balance between these errors depends on the financial cost of retention campaigns and the cost of losing customers.

## Deployment

The final trained model was saved as:

```text
final_churn_model.joblib
```

A FastAPI application was created with the following endpoints:

- GET `/health` — checks whether the API is running.
- POST `/predict` — accepts customer information and returns a churn prediction and probability.

### Example API Request

```json
{
  "membership_tier": "Gold",
  "preferred_channel": "Website",
  "state": "Lagos",
  "referral_source": "Social Media",
  "marketing_opt_in": 1,
  "Frequency": 4,
  "Monetary_Total": 6500,
  "Monetary_Average": 1625,
  "Support_Ticket_Count": 2,
  "Average_Satisfaction": 4.0,
  "Average_Resolution_Time": 24.0
}
```

### Example API Response

```json
{
  "prediction": 1,
  "churn_label": "Churned",
  "churn_probability": 0.6604
}
```

Invalid or missing input fields are handled using API validation errors rather than allowing the application to fail silently.

## Key Project Findings

- Customer churn was substantial within the analysed customer population.
- Recency showed a strong relationship with churn during exploratory analysis.
- Purchasing frequency and monetary value were major contributors to machine-learning predictions.
- Support-resolution time provided an additional predictive signal.
- Support-ticket count and satisfaction contributed smaller individual amounts to the final Random Forest model.
- The churn model provides useful predictive information but should not be treated as a perfect predictor of future customer behavior.

## Limitations

Important limitations include:

- The churn target is based on historical inactivity and therefore reflects the chosen business definition.
- Customer behavior can change after the observation period.
- Some support-ticket satisfaction information is missing.
- Model performance is moderate and should be validated on future customer data before production use.
- The model identifies statistical patterns and does not establish that a feature directly causes churn.
- Further testing would be required to determine whether retention interventions actually reduce churn.

## Required Libraries

The project uses Python libraries including:

- pandas
- numpy
- matplotlib
- seaborn
- plotly
- scikit-learn
- shap
- joblib
- fastapi
- uvicorn
- python-pptx

## How to Run the Analysis

The analysis notebooks were developed for Google Colab.

1. Mount Google Drive.
2. Confirm that the Meridian Retail Group project folder is available.
3. Run the notebooks in phase order.
4. Complete the data preparation and cleaning stages before running the analysis.
5. Run Phase 7 for customer-level churn analysis.
6. Run Phase 8 for visualizations.
7. Run Phase 9 for machine learning, explainability and deployment.

## How to Run the API

From the deployment directory, install the required packages and start the FastAPI application with Uvicorn.

Example:

```bash
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8000
```

The prediction endpoint is:

```text
POST /predict
```

## Project Deliverables

The project includes:

- Cleaned datasets
- Exploratory data analysis
- Visualization outputs
- Model evaluation results
- Hyperparameter tuning results
- SHAP explainability outputs
- Saved final machine-learning model
- FastAPI deployment
- API validation tests
- Final presentation
- README documentation

## Conclusion

This project demonstrates an end-to-end approach to investigating customer churn, from data preparation and exploratory analysis through machine learning, explainability and API deployment.

The findings provide Meridian Retail Group with a framework for identifying customers who may require retention attention while highlighting the importance of monitoring purchasing behavior and customer-support experiences.