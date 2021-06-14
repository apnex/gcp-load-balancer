exports.evalPath = (req, res) => {
	let path = req.path.split('/').slice(1);
	let repo = path.shift();
	let newpath;
	if(path.length > 0) {
		newpath = 'https://raw.apnex.io/' + repo + '/master/' + path.join('/');
	} else {
		newpath = 'https://github.com/apnex/' + repo
	}
	res.redirect(newpath);
};
