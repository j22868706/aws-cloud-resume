async function get_visitors() {
    try {
        let response = await fetch('https://rkqfc6sxfrcbszxdakh6lqseme0ajaxz.lambda-url.us-east-2.on.aws/', {
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