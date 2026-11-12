import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from mlxtend.preprocessing import TransactionEncoder
from mlxtend.frequent_patterns import apriori, association_rules

# page configuration
st.set_page_config(
    page_title="Campus Food Insights Dashboard",
    page_icon="🍽️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# cached data loader
@st.cache_data
def load_clean_data():
    df = pd.read_csv("data/clean.csv")
    return df

df_raw = load_clean_data()

# sidebar title and filters
st.sidebar.title("🔍 Filter Data")
st.sidebar.markdown("Filter responses to update all metrics and charts dynamically.")

all_years = sorted(df_raw["year"].unique())
sel_year = st.sidebar.multiselect("Year of Study", options=all_years, default=all_years)

all_res = sorted(df_raw["residence"].unique())
sel_res = st.sidebar.multiselect("Residence", options=all_res, default=all_res)

all_gen = sorted(df_raw["gender"].unique())
sel_gen = st.sidebar.multiselect("Gender", options=all_gen, default=all_gen)

all_diet = sorted(df_raw["diet"].unique())
sel_diet = st.sidebar.multiselect("Dietary Preference", options=all_diet, default=all_diet)

# apply filters
df = df_raw[
    (df_raw["year"].isin(sel_year)) &
    (df_raw["residence"].isin(sel_res)) &
    (df_raw["gender"].isin(sel_gen)) &
    (df_raw["diet"].isin(sel_diet))
].copy()

# header
st.title("🍽️ Campus Food Insights Dashboard")
st.markdown("A data-driven exploration of student dining habits, spending, satisfaction, and mined behavior patterns.")

if df.empty:
    st.warning("No survey responses match the selected filters. Please broaden your selection.")
    st.stop()

# top KPI row
kpi1, kpi2, kpi3, kpi4, kpi5 = st.columns(5)
total_resp = len(df)
avg_spend = df["spend_mid"].mean()
avg_sat = df["satisfaction"].mean()
pct_skip_bf = (df["skipped_meal"] == "Breakfast").mean() * 100
pct_satisfied = (df["satisfaction"] >= 4).mean() * 100

kpi1.metric("Total Responses", f"{total_resp}")
kpi2.metric("Avg Monthly Spend", f"Rs. {avg_spend:.0f}")
kpi3.metric("Avg Satisfaction", f"{avg_sat:.2f} / 5.0")
kpi4.metric("Skips Breakfast", f"{pct_skip_bf:.1f}%")
kpi5.metric("Satisfied (4-5)", f"{pct_satisfied:.1f}%")

st.markdown("---")

# tabs
tab_overview, tab_eda, tab_patterns, tab_clusters, tab_insights = st.tabs([
    "📊 Overview",
    "📈 EDA & Relationships",
    "🔗 Association Rules",
    "🎯 Student Clusters",
    "💡 Insights & Recommendations"
])

# ----------------- TAB 1: OVERVIEW -----------------
with tab_overview:
    st.subheader("Demographic & Baseline Distributions")
    
    col_a, col_b, col_c = st.columns(3)
    
    with col_a:
        fig_year = px.bar(
            df["year"].value_counts().reset_index(),
            x="year", y="count",
            title="Year of Study",
            labels={"year": "Year", "count": "Count"},
            color_discrete_sequence=["#4C72B0"]
        )
        st.plotly_chart(fig_year, use_container_width=True)
        
    with col_b:
        fig_res = px.pie(
            df["residence"].value_counts().reset_index(),
            names="residence", values="count",
            title="Residence Type",
            color_discrete_sequence=["#DD8452", "#4C72B0"]
        )
        st.plotly_chart(fig_res, use_container_width=True)
        
    with col_c:
        fig_gen = px.bar(
            df["gender"].value_counts().reset_index(),
            x="gender", y="count",
            title="Gender Distribution",
            labels={"gender": "Gender", "count": "Count"},
            color_discrete_sequence=["#55A868"]
        )
        st.plotly_chart(fig_gen, use_container_width=True)

    col_d, col_e, col_f = st.columns(3)
    
    with col_d:
        fig_diet = px.bar(
            df["diet"].value_counts().reset_index(),
            x="diet", y="count",
            title="Dietary Preference",
            labels={"diet": "Diet", "count": "Count"},
            color_discrete_sequence=["#C44E52"]
        )
        st.plotly_chart(fig_diet, use_container_width=True)
        
    with col_e:
        fig_skip = px.bar(
            df["skipped_meal"].value_counts().reset_index(),
            x="skipped_meal", y="count",
            title="Most Skipped Meal",
            labels={"skipped_meal": "Meal", "count": "Count"},
            color_discrete_sequence=["#8172B3"]
        )
        st.plotly_chart(fig_skip, use_container_width=True)
        
    with col_f:
        fig_pay = px.bar(
            df["payment"].value_counts().reset_index(),
            x="payment", y="count",
            title="Payment Method",
            labels={"payment": "Payment Method", "count": "Count"},
            color_discrete_sequence=["#937860"]
        )
        st.plotly_chart(fig_pay, use_container_width=True)

    st.subheader("Spend & Satisfaction Distributions")
    col_g, col_h = st.columns(2)
    
    with col_g:
        fig_spend = px.histogram(
            df, x="spend_mid", nbins=10,
            title="Monthly Spend Distribution (INR)",
            labels={"spend_mid": "Monthly Food Spend (INR)"},
            color_discrete_sequence=["#CCB974"]
        )
        st.plotly_chart(fig_spend, use_container_width=True)
        
    with col_h:
        fig_sat = px.bar(
            df["satisfaction"].value_counts().sort_index().reset_index(),
            x="satisfaction", y="count",
            title="Overall Food Satisfaction Rating (1 to 5)",
            labels={"satisfaction": "Satisfaction Rating", "count": "Count"},
            color_discrete_sequence=["#4C72B0"]
        )
        fig_sat.update_xaxes(tickvals=[1, 2, 3, 4, 5])
        st.plotly_chart(fig_sat, use_container_width=True)

# ----------------- TAB 2: EDA & RELATIONSHIPS -----------------
with tab_eda:
    st.subheader("Subgroup Comparisons")
    
    eda_col1, eda_col2 = st.columns(2)
    
    with eda_col1:
        sat_by_group = df.groupby("year")["satisfaction"].agg(["mean", "count"]).reset_index()
        sat_by_group.columns = ["Year", "Mean Satisfaction", "Count"]
        fig_sat_yr = px.bar(
            sat_by_group, x="Year", y="Mean Satisfaction", text=sat_by_group["Mean Satisfaction"].round(2),
            title="Mean Satisfaction by Year of Study",
            color="Year", color_discrete_sequence=px.colors.qualitative.Set2
        )
        fig_sat_yr.update_yaxes(range=[0, 5])
        st.plotly_chart(fig_sat_yr, use_container_width=True)
        
    with eda_col2:
        sat_by_diet = df.groupby("diet")["satisfaction"].agg(["mean", "count"]).reset_index()
        sat_by_diet.columns = ["Diet", "Mean Satisfaction", "Count"]
        fig_sat_diet = px.bar(
            sat_by_diet, x="Diet", y="Mean Satisfaction", text=sat_by_diet["Mean Satisfaction"].round(2),
            title="Mean Satisfaction by Dietary Preference",
            color="Diet", color_discrete_sequence=px.colors.qualitative.Pastel
        )
        fig_sat_diet.update_yaxes(range=[0, 5])
        st.plotly_chart(fig_sat_diet, use_container_width=True)

    eda_col3, eda_col4 = st.columns(2)
    
    with eda_col3:
        fig_box_spend = px.box(
            df, x="gender", y="spend_mid", color="gender",
            title="Monthly Food Spend by Gender",
            labels={"gender": "Gender", "spend_mid": "Monthly Spend (INR)"}
        )
        st.plotly_chart(fig_box_spend, use_container_width=True)
        
    with eda_col4:
        fig_box_yr_spend = px.box(
            df, x="year", y="spend_mid", color="year",
            title="Monthly Food Spend by Year of Study",
            labels={"year": "Year", "spend_mid": "Monthly Spend (INR)"}
        )
        st.plotly_chart(fig_box_yr_spend, use_container_width=True)

    st.subheader("Correlation Heatmap & Outlet Satisfaction")
    eda_col5, eda_col6 = st.columns(2)
    
    with eda_col5:
        num_cols = ["satisfaction", "spend_mid", "meals_num", "outside_num"]
        cor_matrix = df[num_cols].corr().round(3)
        fig_heatmap = px.imshow(
            cor_matrix,
            text_auto=True,
            color_continuous_scale="RdBu_r",
            zmin=-1, zmax=1,
            title="Correlation Heatmap (Numeric Variables)"
        )
        st.plotly_chart(fig_heatmap, use_container_width=True)
        
    with eda_col6:
        # outlet satisfaction comparison
        major_outlets = ["Hostel Mess", "Nescafe", "Yadav Canteen", "Night Canteen", "Snacker"]
        outlet_stats = []
        for out in major_outlets:
            mask = df["outlets"].str.contains(out, na=False)
            if mask.sum() > 0:
                outlet_stats.append({
                    "Outlet": out,
                    "Mean Satisfaction": round(df.loc[mask, "satisfaction"].mean(), 2),
                    "Users": mask.sum()
                })
        df_outlets = pd.DataFrame(outlet_stats)
        fig_outlet_sat = px.bar(
            df_outlets, x="Outlet", y="Mean Satisfaction", text="Mean Satisfaction",
            title="Mean Overall Satisfaction by Outlet Used",
            color="Outlet", color_discrete_sequence=px.colors.qualitative.Safe
        )
        fig_outlet_sat.update_yaxes(range=[0, 5])
        st.plotly_chart(fig_outlet_sat, use_container_width=True)

# ----------------- TAB 3: ASSOCIATION RULES -----------------
with tab_patterns:
    st.subheader("Association Rules Mining (Apriori)")
    st.markdown("Discovers frequent combinations of outlets, priority factors, improvements, and student dining behaviors.")
    
    col_rule_ctrl1, col_rule_ctrl2 = st.columns(2)
    with col_rule_ctrl1:
        min_supp = st.slider("Minimum Support", min_value=0.08, max_value=0.25, value=0.12, step=0.01)
    with col_rule_ctrl2:
        min_conf = st.slider("Minimum Confidence", min_value=0.50, max_value=0.90, value=0.60, step=0.05)
        
    # prepare transactions from filtered data
    transactions = []
    for _, row in df.iterrows():
        outs = [f"outlet={x.strip()}" for x in str(row["outlets"]).split(",") if x.strip()]
        facts = [f"factor={x.strip()}" for x in str(row["factors"]).split(",") if x.strip()]
        imprs = [f"improve={x.strip()}" for x in str(row["improvements"]).split(",") if x.strip()]
        
        sp = "spend=Low" if row["spend_mid"] <= 1000 else ("spend=Medium" if row["spend_mid"] <= 2000 else "spend=High")
        sat = "sat=Satisfied" if row["satisfaction"] >= 4 else ("sat=Neutral" if row["satisfaction"] == 3 else "sat=Dissatisfied")
        skip = f"skip={row['skipped_meal']}"
        diet = f"diet={row['diet']}"
        
        itemset = set(outs + facts + imprs + [sp, sat, skip, diet])
        transactions.append(list(itemset))
        
    te = TransactionEncoder()
    te_ary = te.fit(transactions).transform(transactions)
    df_trans = pd.DataFrame(te_ary, columns=te.columns_)
    
    # calculate item frequencies
    item_freq = df_trans.mean().reset_index()
    item_freq.columns = ["Item", "Support"]
    item_freq = item_freq.sort_values(by="Support", ascending=False).head(15)
    
    fig_freq = px.bar(
        item_freq, x="Item", y="Support", text=item_freq["Support"].round(3),
        title="Top 15 Most Frequent Items (Item Frequency / Support)",
        color_discrete_sequence=["#4C72B0"]
    )
    st.plotly_chart(fig_freq, use_container_width=True)
    
    frequent_items = apriori(df_trans, min_support=min_supp, use_colnames=True)
    
    if frequent_items.empty:
        st.info("No frequent itemsets found for the selected support threshold. Try lowering the minimum support.")
    else:
        rules = association_rules(frequent_items, metric="confidence", min_threshold=min_conf)
        if rules.empty:
            st.info("No rules meet the current confidence threshold. Try lowering the minimum confidence.")
        else:
            rules = rules.sort_values(by="lift", ascending=False)
            rules["antecedents"] = rules["antecedents"].apply(lambda x: ", ".join(list(x)))
            rules["consequents"] = rules["consequents"].apply(lambda x: ", ".join(list(x)))
            
            show_cols = ["antecedents", "consequents", "support", "confidence", "lift"]
            display_rules = rules[show_cols].copy()
            display_rules["support"] = display_rules["support"].round(3)
            display_rules["confidence"] = display_rules["confidence"].round(3)
            display_rules["lift"] = display_rules["lift"].round(3)
            
            st.markdown(f"**Found {len(display_rules)} rules meeting criteria. Showing top rules sorted by Lift:**")
            st.dataframe(display_rules.head(20), use_container_width=True)

# ----------------- TAB 4: STUDENT CLUSTERS -----------------
with tab_clusters:
    st.subheader("Student Segmentation (K-Means Clustering)")
    st.markdown("Segments students based on Monthly Spend, Satisfaction Rating, Outside Deliveries, and Campus Meals per day.")
    
    clust_features = ["spend_mid", "satisfaction", "outside_num", "meals_num"]
    scaler = StandardScaler()
    scaled_matrix = scaler.fit_transform(df[clust_features])
    
    col_km1, col_km2 = st.columns([1, 2])
    
    with col_km1:
        # elbow curve
        inertias = []
        k_range = range(1, min(9, len(df)))
        for k in k_range:
            km = KMeans(n_clusters=k, random_state=42, n_init=10)
            km.fit(scaled_matrix)
            inertias.append(km.inertia_)
            
        fig_elbow = px.line(
            x=list(k_range), y=inertias, markers=True,
            title="Elbow Method Curve",
            labels={"x": "Number of Clusters (k)", "y": "Inertia (Within-SS)"},
            color_discrete_sequence=["#4C72B0"]
        )
        st.plotly_chart(fig_elbow, use_container_width=True)
        
        chosen_k = st.selectbox("Select k (Clusters)", options=[2, 3, 4], index=1)
        
    with col_km2:
        kmeans_model = KMeans(n_clusters=chosen_k, random_state=42, n_init=20)
        df_clustered = df.copy()
        df_clustered["Cluster"] = [f"Cluster {c+1}" for c in kmeans_model.fit_predict(scaled_matrix)]
        
        # summary table
        cluster_means = df_clustered.groupby("Cluster")[clust_features].mean().round(2).reset_index()
        cluster_counts = df_clustered["Cluster"].value_counts().reset_index()
        cluster_counts.columns = ["Cluster", "Students"]
        cluster_summary = pd.merge(cluster_counts, cluster_means, on="Cluster")
        
        st.markdown("**Cluster Profiles (Averages):**")
        st.dataframe(cluster_summary, use_container_width=True)
        
    fig_scatter = px.scatter(
        df_clustered,
        x="spend_mid", y="satisfaction",
        color="Cluster",
        hover_data=["year", "diet", "outside_num", "meals_num"],
        title="Student Clusters: Monthly Spend vs Satisfaction",
        labels={"spend_mid": "Monthly Food Spend (INR)", "satisfaction": "Satisfaction (1-5)"},
        color_discrete_sequence=px.colors.qualitative.Set1
    )
    st.plotly_chart(fig_scatter, use_container_width=True)
    
    st.markdown("""
    **Segment Descriptions (k = 3):**
    - **Cluster 1 (Dissatisfied Infrequent Campus Diners)**: Low satisfaction (~2.08), lowest campus meal participation (~0.38 meals/day), moderate spend.
    - **Cluster 2 (Budget Regular Campus Diners)**: Modest spend (~Rs. 1,445), highest campus meal reliance (~1.38 meals/day), moderate satisfaction (~3.19).
    - **Cluster 3 (High Spenders & High Satisfaction)**: Highest monthly food budget (~Rs. 2,767), frequent outside deliveries (~1.47/wk), highest satisfaction (~4.07).
    """)

# ----------------- TAB 5: INSIGHTS & RECOMMENDATIONS -----------------
with tab_insights:
    st.subheader("💡 Strategic Insights & Key Takeaways")
    
    col_ins1, col_ins2 = st.columns(2)
    
    with col_ins1:
        st.markdown("""
        ### Key Analytical Findings
        1. **Universal Breakfast Skipping**:
           - **70.5%** of students report skipping breakfast most frequently. This is widespread across batches, hostel wings, and dietary preferences.
        2. **Budget and Satisfaction Polarization**:
           - Monthly extra spend is the single statistically significant predictor of satisfaction (`p = 0.0414`).
           - Students with budgets above Rs. 2,000 supplement meals freely and achieve higher satisfaction (**4.07**), while students on strict budgets (**Rs. 1,000–1,500**) rely on the mess and remain neutral to dissatisfied.
        3. **Hostel Mess Vegetarian Demand**:
           - Association rules reveal that students asking for better food quality and taste in the hostel mess are overwhelmingly **Vegetarian** (`confidence = 86.7%`, `lift = 1.96`).
        4. **Complete Shift to Digital Payments**:
           - **97.7%** use UPI/QR code transactions, reflecting total cash displacement on campus.
        """)
        
    with col_ins2:
        st.markdown("""
        ### Actionable Recommendations for Campus Food Services
        1. **Grab-and-Go Morning Kiosks**:
           - Set up morning quick-service counters (8:00 AM – 10:30 AM) with pre-packaged nutritious breakfasts (poha, parathas, fruit cups, boiled eggs, rolls) near hostels to directly tackle the 70.5% breakfast skipping.
        2. **Hostel Mess Quality & Hygiene Audits**:
           - Conduct scheduled student-led hygiene inspections and revamp vegetarian menus with higher variety and protein options.
        3. **Value Combos for Budget Diners**:
           - Introduce subsidized daily combo meals (Rs. 60–100) at outlets like Nescafe, Yadav Canteen, and Snacker to cater to the 47 students in the budget dining cluster.
        4. **High-Speed UPI Billing Counters**:
           - Dedicated QR scanning points and stable WiFi/network boosters at billing desks to eliminate peak lunch/snack queues.
        """)

