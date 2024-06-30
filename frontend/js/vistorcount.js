async function get_visitors() {
    try {
        let response = await fetch('https://k48zb5x5z8.execute-api.us-east-2.amazonaws.com/prod', {
            method: 'GET',
        });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        let data = await response.json();
        document.getElementById("visitors").innerHTML = data['count'];
        console.log(data);
        return data;
    } catch (err) {
        console.error('Error fetching visitor count:', err);
        document.getElementById("visitors").innerHTML = "Error loading count";
    }
}

get_visitors();