import pandas as pd
import vertexai
from vertexai.generative_models import GenerativeModel, Part, FinishReason
import vertexai.preview.generative_models as generative_models
import re
import time
import numpy as np

generation_config = {
    "max_output_tokens": 200,
    "temperature": 0.7
}

safety_settings = {
    generative_models.HarmCategory.HARM_CATEGORY_HATE_SPEECH: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_HARASSMENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
}

num_questions = 3

vertexai.init(project="cloud-llm-preview1", location="us-central1")
model = GenerativeModel(
"gemini-1.5-flash-preview-0514",
)

def filter_low_value_count_rows(df, column_name, min_count=10):
    """
    Removes rows from a DataFrame where the value count in the specified column is less than the given minimum count.

    Args:
        df: The Pandas DataFrame to filter.
        column_name: The name of the column to check value counts for.
        min_count: The minimum value count required for a row to be kept (default: 10).

    Returns:
        A new DataFrame with rows removed where value counts are below the threshold.
    """

    # Calculate value counts for the specified column
    value_counts = df[column_name].value_counts()

    # Filter values that meet the minimum count criteria
    filtered_values = value_counts[value_counts >= min_count].index

    # Create a new DataFrame keeping only rows with those values
    filtered_df = df[df[column_name].isin(filtered_values)]

    return filtered_df


def prep_context():
    temp1 = pd.read_csv("gs://gkebatchexpce3c8dcb-dev-processing/flipkart_preprocessed_dataset/flipkart.csv")
    # renaming column name
    temp1.rename(columns={'uniq_id': 'Id', 'product_name': 'Name', 'description': 'Description', 'brand': 'Brand',
                          'attributes': 'Specifications'}, inplace=True)
    df = temp1[['Name', 'Description', 'Specifications', 'Brand', 'c0_name', 'c1_name', 'c2_name', 'c3_name']]

    # Filter only clothing products
    filtered_df = df[df['c0_name'] == 'Clothing']

    # Filter only Women, Men & Kids clothing products
    values_to_filter = ["Women's Clothing", "Men's Clothing", "Kids' Clothing"]
    clothing_filtered_df = filtered_df[filtered_df['c1_name'].isin(values_to_filter)]

    # Filter to keep rows where 'c2_name' has count >=10
    c2_filtered_df = filter_low_value_count_rows(clothing_filtered_df, 'c2_name', min_count=10)

    # Filter to keep rows where 'c3_name' has count >=10
    c3_filtered_df = filter_low_value_count_rows(c2_filtered_df, 'c3_name', min_count=10)

    # Data Format expected for finetuning: {"context": " ", "question": " ", "answer": " "}
    context_df = c3_filtered_df[[
        'Name',
        'Description',
        'c1_name',
        'Specifications']]
    finetune_ds = pd.DataFrame(columns=['context', 'question', 'answer'])
    finetune_ds['context'] = "Product Name: " + context_df['Name'] + "<br> Product Category: " + context_df[
        'c1_name'] + "<br> Attributes: " + context_df['Specifications'] + " <br> Description: " + context_df[
                                 'Description']

    return finetune_ds


def generate(context, category):
  prompt = f"Generate {num_questions} Search Queries in conversational tone and Answers for this product:\n{context}. Return the result without any formatting in a single line as Question : Answer"
  try:
    responses = model.generate_content(
        [prompt],
        generation_config=generation_config,
        safety_settings=safety_settings,
        stream=True,
    )
    qa=''
    for response in responses:
      qa+=response.text
    #print (qa)

    # Define the pattern to match questions and answers
    pattern = r"Question : (.*?) : Answer : (.*?)(?=\nQuestion :|$)"  # $ for end of string

    # Extract questions and answers
    matches = re.findall(pattern, qa, re.DOTALL)
    #print(matches)

    # Create a DataFrame
    temp_df = pd.DataFrame(matches, columns=["Question", "Answer"])
    temp_df['Context'] = context
    temp_df['Category'] = category
    return temp_df
  except Exception as e:
    print(e)
    return None

def data_prep(finetune_ds):
    result = pd.DataFrame()
    for (context, category) in finetune_ds[['context','c1_name']]:
      if context!=np.nan:
        temp_df = generate(context, category)
        if not temp_df is None:
          result = pd.concat([result, temp_df], ignore_index=True)
        time.sleep(1) # Add a 1 second delay to avoid API rate limiting (adjust as needed)

    # Now `result` contains all generated questions and answers
    print(result)

if __name__ == '__main__':
    df = prep_context()
    data_prep(df)
