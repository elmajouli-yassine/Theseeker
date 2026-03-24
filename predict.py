import sys
import pickle
import json
import os

def predict():
    if not os.path.exists('path_predictor.pkl'):
        print(json.dumps([]))
        return

    with open('path_predictor.pkl', 'rb') as f:
        model = pickle.load(f)

    # Read CewL keywords passed as the first argument
    try:
        with open(sys.argv[1], 'r') as f:
            keywords = [line.strip() for line in f.readlines() if line.strip()]
        
        # Predict paths and remove duplicates
        preds = list(set(model.predict(keywords)))
        print(json.dumps(preds))
    except:
        print(json.dumps([]))

if __name__ == "__main__":
    predict()
